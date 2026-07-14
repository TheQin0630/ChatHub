#include "ProtocolAdapter.h"

#include <QtGlobal>
#include <QVariantMap>
#include <cstring>

namespace {
constexpr int FlagRetain = 0x01;
constexpr int FlagQosShift = 1;
constexpr int FlagQosMask = 0x06;
constexpr int FlagDup = 0x08;

QString formatIPv4(const unsigned char ip[4])
{
    return QStringLiteral("%1.%2.%3.%4").arg(ip[0]).arg(ip[1]).arg(ip[2]).arg(ip[3]);
}
}

QByteArray ProtocolAdapter::pack(MessageType type, const QString &topic, const QByteArray &payload)
{
    Frame frame;
    frame.type = type;
    frame.topic = topic;
    frame.payload = payload;
    return packFrame(frame);
}

QByteArray ProtocolAdapter::packFrame(const Frame &frame)
{
    QByteArray payload = frame.payload;
    if (frame.type == PublishEx || frame.type == Deliver) {
        QByteArray inner;
        inner.resize(PublishExHeaderBytes + frame.payload.size());
        int flags = 0;
        if (frame.retain) flags |= FlagRetain;
        flags |= (frame.qos << FlagQosShift) & FlagQosMask;
        if (frame.dup) flags |= FlagDup;
        inner[0] = static_cast<char>(flags);
        writeU16(&inner, 1, frame.packetId);
        writeU16(&inner, 3, frame.payload.size());
        if (!frame.payload.isEmpty()) {
            std::memcpy(inner.data() + PublishExHeaderBytes, frame.payload.constData(), frame.payload.size());
        }
        payload = inner;
    } else if (frame.type == PubRec1 || frame.type == DeliverAck) {
        payload.resize(AckPayloadBytes);
        writeU16(&payload, 0, frame.packetId);
        payload[2] = 0;
    }

    const QByteArray topicBytes = frame.topic.toUtf8();
    QByteArray out;
    out.resize(HeaderBytes + topicBytes.size() + payload.size());
    out[0] = static_cast<char>(frame.type);
    out[1] = static_cast<char>(topicBytes.size());
    writeU16(&out, 2, payload.size());
    if (!topicBytes.isEmpty()) {
        std::memcpy(out.data() + HeaderBytes, topicBytes.constData(), topicBytes.size());
    }
    if (!payload.isEmpty()) {
        std::memcpy(out.data() + HeaderBytes + topicBytes.size(), payload.constData(), payload.size());
    }
    return out;
}

QByteArray ProtocolAdapter::packPageRequest(int requestId, int offset, int limit, int order)
{
    QByteArray payload(PageRequestBytes, Qt::Uninitialized);
    writeU16(&payload, 0, requestId);
    writeU16(&payload, 2, offset);
    writeU16(&payload, 4, limit);
    payload[6] = static_cast<char>(order);
    return payload;
}

ProtocolAdapter::Frame ProtocolAdapter::makeExtendedPublish(const QString &topic, const QByteArray &payload, int qos, bool retain, int packetId, bool dup)
{
    Frame frame;
    frame.type = PublishEx;
    frame.topic = topic;
    frame.payload = payload;
    frame.qos = qBound(0, qos, 1);
    frame.retain = retain;
    frame.dup = dup;
    frame.packetId = frame.qos == 1 ? packetId : 0;
    return frame;
}

ProtocolAdapter::Frame ProtocolAdapter::makeDeliverAck(const QString &topic, int packetId)
{
    Frame frame;
    frame.type = DeliverAck;
    frame.topic = topic;
    frame.packetId = packetId;
    return frame;
}

ProtocolAdapter::ParseResult ProtocolAdapter::tryParse(QByteArray *buffer, Frame *frame, QString *error)
{
    if (!buffer || !frame) {
        if (error) *error = QStringLiteral("parser argument is null");
        return ParseResult::Invalid;
    }
    if (buffer->size() < HeaderBytes) {
        return ParseResult::Incomplete;
    }

    const int type = static_cast<unsigned char>(buffer->at(0));
    const int topicLen = static_cast<unsigned char>(buffer->at(1));
    const int payloadLen = readU16(*buffer, 2);
    if (type < Subscribe || type > UnsubscribeFdNotify) {
        if (error) *error = QStringLiteral("unknown message type: %1").arg(type);
        buffer->remove(0, 1);
        return ParseResult::Invalid;
    }
    if (topicLen > MaxTopicBytes || payloadLen > MaxPayloadBytes) {
        if (error) *error = QStringLiteral("frame field too long: topic=%1 payload=%2").arg(topicLen).arg(payloadLen);
        buffer->clear();
        return ParseResult::Invalid;
    }

    const int total = HeaderBytes + topicLen + payloadLen;
    if (buffer->size() < total) {
        return ParseResult::Incomplete;
    }

    frame->type = static_cast<MessageType>(type);
    frame->topic = QString::fromUtf8(buffer->mid(HeaderBytes, topicLen));
    frame->payload = buffer->mid(HeaderBytes + topicLen, payloadLen);
    frame->flags = 0;
    frame->qos = 0;
    frame->retain = false;
    frame->dup = false;
    frame->packetId = 0;
    frame->alias.clear();
    frame->rejectCode = 0;
    frame->rejectReason.clear();
    buffer->remove(0, total);

    if (frame->type == PublishEx || frame->type == Deliver) {
        if (frame->payload.size() < PublishExHeaderBytes) {
            if (error) *error = QStringLiteral("extended publish payload is too short");
            return ParseResult::Invalid;
        }
        frame->flags = static_cast<unsigned char>(frame->payload.at(0));
        frame->retain = (frame->flags & FlagRetain) != 0;
        frame->qos = (frame->flags & FlagQosMask) >> FlagQosShift;
        frame->dup = (frame->flags & FlagDup) != 0;
        frame->packetId = readU16(frame->payload, 1);
        const int innerLen = readU16(frame->payload, 3);
        if (frame->qos > 1 || (frame->qos == 1 && frame->packetId == 0) || innerLen > frame->payload.size() - PublishExHeaderBytes) {
            if (error) *error = QStringLiteral("invalid extended publish fields");
            return ParseResult::Invalid;
        }
        const QByteArray extendedPayload = frame->payload;
        const int aliasOffset = PublishExHeaderBytes + innerLen;
        if (frame->type == Deliver && aliasOffset < extendedPayload.size()) {
            const int aliasLen = static_cast<unsigned char>(extendedPayload.at(aliasOffset));
            if (aliasLen > MaxAliasBytes || aliasOffset + 1 + aliasLen != extendedPayload.size()) {
                if (error) *error = QStringLiteral("invalid delivery alias fields");
                return ParseResult::Invalid;
            }
            frame->alias = QString::fromUtf8(extendedPayload.mid(aliasOffset + 1, aliasLen));
        }
        frame->payload = extendedPayload.mid(PublishExHeaderBytes, innerLen);
    } else if (frame->type == Publish && frame->payload.size() >= 3) {
        const int dataLen = readU16(frame->payload, 0);
        const int aliasOffset = 2 + dataLen;
        if (dataLen <= frame->payload.size() - 3 && aliasOffset < frame->payload.size()) {
            const int aliasLen = static_cast<unsigned char>(frame->payload.at(aliasOffset));
            if (aliasLen <= MaxAliasBytes && aliasOffset + 1 + aliasLen == frame->payload.size()) {
                const QByteArray forwardedPayload = frame->payload;
                frame->payload = forwardedPayload.mid(2, dataLen);
                frame->alias = QString::fromUtf8(forwardedPayload.mid(aliasOffset + 1, aliasLen));
            }
        }
    } else if (frame->type == PubRec1 || frame->type == DeliverAck) {
        if (frame->payload.size() >= 2) {
            frame->packetId = readU16(frame->payload, 0);
        }
    } else if (frame->type == SubscribeReject || frame->type == PublishReject) {
        // Future protocol: reject messages
        parseRejectFrame(frame->payload, &frame->rejectCode, &frame->rejectReason);
    }

    return ParseResult::Complete;
}

bool ProtocolAdapter::isTopicValid(const QString &topic, QString *error)
{
    const QString trimmed = topic.trimmed();
    if (trimmed.isEmpty()) {
        if (error) *error = QStringLiteral("channel cannot be empty");
        return false;
    }
    const QByteArray bytes = trimmed.toUtf8();
    if (bytes.size() > MaxTopicBytes) {
        if (error) *error = QStringLiteral("channel max length is %1 bytes").arg(MaxTopicBytes);
        return false;
    }
    if (trimmed.contains(QChar::Space) || trimmed.contains('\n') || trimmed.contains('\r') || trimmed.contains('\t')) {
        if (error) *error = QStringLiteral("channel cannot contain whitespace");
        return false;
    }
    return true;
}

bool ProtocolAdapter::isPayloadValid(const QByteArray &payload, QString *error)
{
    if (payload.isEmpty()) {
        if (error) *error = QStringLiteral("message cannot be empty");
        return false;
    }
    if (payload.size() > MaxPayloadBytes - PublishExHeaderBytes) {
        if (error) *error = QStringLiteral("message max length is %1 bytes; current is %2 bytes")
                .arg(MaxPayloadBytes - PublishExHeaderBytes)
                .arg(payload.size());
        return false;
    }
    return true;
}

QByteArray ProtocolAdapter::makeChatPayload(const QString &nickname, const QString &message)
{
    return (nickname.trimmed() + QChar('\t') + message).toUtf8();
}

void ProtocolAdapter::parseChatPayload(const QByteArray &payload, QString *nickname, QString *message)
{
    const QString text = QString::fromUtf8(payload);
    const qsizetype sep = text.indexOf('\t');
    if (sep > 0) {
        if (nickname) *nickname = text.left(sep);
        if (message) *message = text.mid(sep + 1);
        return;
    }
    if (nickname) *nickname = QStringLiteral("remote");
    if (message) *message = text;
}

bool ProtocolAdapter::parsePageHeader(const QByteArray &payload, PageInfo *info)
{
    if (!info || payload.size() < PageResponseHeaderBytes) {
        return false;
    }
    info->requestId = readU16(payload, 0);
    info->totalItems = readU16(payload, 2);
    info->offset = readU16(payload, 4);
    info->returnedCount = readU16(payload, 6);
    info->hasMore = static_cast<unsigned char>(payload.at(8)) != 0;
    return true;
}

QStringList ProtocolAdapter::parseLogPage(const QByteArray &payload, PageInfo *info)
{
    QStringList rows;
    if (!parsePageHeader(payload, info)) {
        return rows;
    }
    int pos = PageResponseHeaderBytes;
    const int expectedRows = qBound(0, info->returnedCount, 50);
    while (pos < payload.size() && rows.size() < expectedRows) {
        const int len = static_cast<unsigned char>(payload.at(pos++));
        if (pos + len > payload.size()) break;
        rows.append(QString::fromUtf8(payload.mid(pos, len)));
        pos += len;
    }
    return rows;
}

QList<ProtocolAdapter::TopicSummary> ProtocolAdapter::parseTopicPage(const QByteArray &payload, PageInfo *info)
{
    QList<TopicSummary> rows;
    if (!parsePageHeader(payload, info)) {
        return rows;
    }
    int pos = PageResponseHeaderBytes;
    const int expectedRows = qBound(0, info->returnedCount, 50);
    while (pos < payload.size() && rows.size() < expectedRows) {
        const int topicLen = static_cast<unsigned char>(payload.at(pos++));
        if (pos + topicLen + 2 > payload.size()) break;
        TopicSummary item;
        item.topic = QString::fromUtf8(payload.mid(pos, topicLen));
        pos += topicLen;
        item.subscriberCount = readU16(payload, pos);
        pos += 2;
        rows.append(item);
    }
    return rows;
}

int ProtocolAdapter::readU16(const QByteArray &data, int offset)
{
    return (static_cast<unsigned char>(data.at(offset)) << 8)
         | static_cast<unsigned char>(data.at(offset + 1));
}

void ProtocolAdapter::writeU16(QByteArray *data, int offset, int value)
{
    (*data)[offset] = static_cast<char>((value >> 8) & 0xff);
    (*data)[offset + 1] = static_cast<char>(value & 0xff);
}

bool ProtocolAdapter::parseRejectFrame(const QByteArray &payload, int *rejectCode, QString *rejectReason)
{
    if (payload.isEmpty()) {
        if (rejectCode) *rejectCode = 0;
        if (rejectReason) *rejectReason = QStringLiteral("unknown");
        return false;
    }

    if (rejectCode) {
        *rejectCode = static_cast<unsigned char>(payload.at(0));
    }

    if (rejectReason && payload.size() > 1) {
        *rejectReason = QString::fromUtf8(payload.mid(1));
    } else if (rejectReason) {
        switch (rejectCode ? *rejectCode : 0) {
        case 1:
            *rejectReason = QStringLiteral("denied by server rule");
            break;
        case 2:
            *rejectReason = QStringLiteral("topic not found");
            break;
        default:
            *rejectReason = QStringLiteral("no reason provided");
            break;
        }
    }

    return true;
}

QByteArray ProtocolAdapter::packRuleSetRequest(int op, unsigned char mask, int fd, const QString &topic)
{
    Q_UNUSED(topic)
    // Payload: [op:1B][mask:1B][fd:4B][topic...]
    QByteArray payload;
    payload.resize(6);
    payload[0] = static_cast<char>(op);
    payload[1] = static_cast<char>(mask);
    // fd as 4 bytes big-endian
    payload[2] = static_cast<char>((fd >> 24) & 0xff);
    payload[3] = static_cast<char>((fd >> 16) & 0xff);
    payload[4] = static_cast<char>((fd >> 8) & 0xff);
    payload[5] = static_cast<char>(fd & 0xff);

    return payload;
}

QByteArray ProtocolAdapter::packFdTopicRelationRequest(int fd)
{
    QByteArray payload;
    payload.resize(4);
    payload[0] = static_cast<char>((fd >> 24) & 0xff);
    payload[1] = static_cast<char>((fd >> 16) & 0xff);
    payload[2] = static_cast<char>((fd >> 8) & 0xff);
    payload[3] = static_cast<char>(fd & 0xff);
    return payload;
}

QByteArray ProtocolAdapter::packTopicCreateRequest(const QString &topic)
{
    Q_UNUSED(topic)
    // No payload needed, topic is in the frame header
    return QByteArray();
}

QByteArray ProtocolAdapter::packTopicDeleteRequest(const QString &topic)
{
    Q_UNUSED(topic)
    // No payload needed, topic is in the frame header
    return QByteArray();
}

QByteArray ProtocolAdapter::packAliasSetRequest(const QString &alias)
{
    QByteArray bytes = alias.toUtf8();
    bytes.truncate(MaxAliasBytes);
    QByteArray payload;
    payload.append(static_cast<char>(bytes.size()));
    payload.append(bytes);
    return payload;
}

QByteArray ProtocolAdapter::packUnsubscribeFdRequest(int fd)
{
    QByteArray payload(4, '\0');
    payload[0] = static_cast<char>((fd >> 24) & 0xff);
    payload[1] = static_cast<char>((fd >> 16) & 0xff);
    payload[2] = static_cast<char>((fd >> 8) & 0xff);
    payload[3] = static_cast<char>(fd & 0xff);
    return payload;
}

QVariantList ProtocolAdapter::parseConnectionList(const QByteArray &payload)
{
    QVariantList result;
    if (payload.size() < 2) return result;

    int count = readU16(payload, 0);
    int pos = 2;

    // Each entry: [fd:4B][ipv4:4B][port:2B][alias_len:1B][alias:N]
    for (int i = 0; i < count && pos + 11 <= payload.size(); ++i) {
        QVariantMap entry;

        // Read fd (4 bytes big-endian)
        int fd = (static_cast<unsigned char>(payload.at(pos)) << 24)
               | (static_cast<unsigned char>(payload.at(pos+1)) << 16)
               | (static_cast<unsigned char>(payload.at(pos+2)) << 8)
               | static_cast<unsigned char>(payload.at(pos+3));
        pos += 4;

        // Read IPv4 (4 bytes)
        unsigned char ip[4];
        for (int j = 0; j < 4; ++j) {
            ip[j] = static_cast<unsigned char>(payload.at(pos++));
        }
        const QString ipStr = formatIPv4(ip);

        // Read port (2 bytes big-endian)
        int port = readU16(payload, pos);
        pos += 2;

        const int aliasLen = static_cast<unsigned char>(payload.at(pos++));
        if (aliasLen > MaxAliasBytes || pos + aliasLen > payload.size()) break;

        entry.insert(QStringLiteral("fd"), fd);
        entry.insert(QStringLiteral("ip"), ipStr);
        entry.insert(QStringLiteral("port"), port);
        entry.insert(QStringLiteral("alias"), QString::fromUtf8(payload.mid(pos, aliasLen)));
        pos += aliasLen;

        result.append(entry);
    }

    return result;
}

QVariantList ProtocolAdapter::parseTopicSubscribers(const QByteArray &payload)
{
    QVariantList result;
    if (payload.isEmpty()) return result;

    int pos = 0;
    int count = 0;
    const int statusCount = payload.size() >= 3 ? readU16(payload, 1) : 0;
    const bool hasStatus = payload.size() >= 3
            && static_cast<unsigned char>(payload.at(0)) <= 1
            && payload.size() >= 3 + statusCount * 11;
    if (hasStatus) {
        count = statusCount;
        pos = 3;
    } else if (payload.size() >= 2) {
        count = readU16(payload, 0);
        pos = 2;
    } else {
        return result;
    }

    for (int i = 0; i < count && pos + 11 <= payload.size(); ++i) {
        QVariantMap entry;
        const int fd = (static_cast<unsigned char>(payload.at(pos)) << 24)
                     | (static_cast<unsigned char>(payload.at(pos + 1)) << 16)
                     | (static_cast<unsigned char>(payload.at(pos + 2)) << 8)
                     | static_cast<unsigned char>(payload.at(pos + 3));
        pos += 4;

        unsigned char ip[4];
        for (int j = 0; j < 4; ++j) {
            ip[j] = static_cast<unsigned char>(payload.at(pos++));
        }
        const int port = readU16(payload, pos);
        pos += 2;
        const int aliasLen = static_cast<unsigned char>(payload.at(pos++));
        if (aliasLen > MaxAliasBytes || pos + aliasLen > payload.size()) break;

        entry.insert(QStringLiteral("fd"), fd);
        entry.insert(QStringLiteral("ip"), formatIPv4(ip));
        entry.insert(QStringLiteral("port"), port);
        entry.insert(QStringLiteral("alias"), QString::fromUtf8(payload.mid(pos, aliasLen)));
        pos += aliasLen;
        result.append(entry);
    }

    return result;
}

int ProtocolAdapter::parseTopicSubscribersStatus(const QByteArray &payload)
{
    if (payload.size() < 3) return -1;
    const int status = static_cast<unsigned char>(payload.at(0));
    if (status > 1) return -1;
    return status;
}

QVariantMap ProtocolAdapter::parseFdTopicRelation(const QByteArray &payload)
{
    QVariantMap result;
    result.insert(QStringLiteral("status"), 1);
    result.insert(QStringLiteral("fd"), 0);
    result.insert(QStringLiteral("mask"), 0);
    if (payload.size() < 6) {
        return result;
    }

    const int fd = (static_cast<unsigned char>(payload.at(1)) << 24)
                 | (static_cast<unsigned char>(payload.at(2)) << 16)
                 | (static_cast<unsigned char>(payload.at(3)) << 8)
                 | static_cast<unsigned char>(payload.at(4));
    result.insert(QStringLiteral("status"), static_cast<unsigned char>(payload.at(0)));
    result.insert(QStringLiteral("fd"), fd);
    result.insert(QStringLiteral("mask"), static_cast<unsigned char>(payload.at(5)));
    if (payload.size() > 6) {
        const int aliasLen = static_cast<unsigned char>(payload.at(6));
        if (aliasLen <= MaxAliasBytes && 7 + aliasLen == payload.size()) {
            result.insert(QStringLiteral("alias"), QString::fromUtf8(payload.mid(7, aliasLen)));
        }
    }
    return result;
}

QString ProtocolAdapter::parseAliasPayload(const QByteArray &payload)
{
    if (payload.isEmpty()) return {};
    const int aliasLen = static_cast<unsigned char>(payload.at(0));
    if (aliasLen > MaxAliasBytes || aliasLen + 1 != payload.size()) return {};
    return QString::fromUtf8(payload.mid(1, aliasLen));
}

QVariantMap ProtocolAdapter::parseSelfConnection(const QByteArray &payload)
{
    QVariantMap result;
    if (payload.size() < 11) return result;
    const int fd = (static_cast<unsigned char>(payload.at(0)) << 24)
            | (static_cast<unsigned char>(payload.at(1)) << 16)
            | (static_cast<unsigned char>(payload.at(2)) << 8)
            | static_cast<unsigned char>(payload.at(3));
    unsigned char ip[4];
    for (int i = 0; i < 4; ++i) ip[i] = static_cast<unsigned char>(payload.at(4 + i));
    const int aliasLen = static_cast<unsigned char>(payload.at(10));
    if (aliasLen > MaxAliasBytes || 11 + aliasLen != payload.size()) return {};
    result.insert(QStringLiteral("fd"), fd);
    result.insert(QStringLiteral("ip"), formatIPv4(ip));
    result.insert(QStringLiteral("port"), readU16(payload, 8));
    result.insert(QStringLiteral("alias"), QString::fromUtf8(payload.mid(11, aliasLen)));
    return result;
}

QVariantMap ProtocolAdapter::parseUnsubscribeFdResponse(const QByteArray &payload)
{
    QVariantMap result;
    if (payload.size() < 5) return result;
    const int fd = (static_cast<unsigned char>(payload.at(0)) << 24)
            | (static_cast<unsigned char>(payload.at(1)) << 16)
            | (static_cast<unsigned char>(payload.at(2)) << 8)
            | static_cast<unsigned char>(payload.at(3));
    const int aliasLen = static_cast<unsigned char>(payload.at(4));
    if (aliasLen > MaxAliasBytes || 5 + aliasLen != payload.size()) return {};
    result.insert(QStringLiteral("fd"), fd);
    result.insert(QStringLiteral("alias"), QString::fromUtf8(payload.mid(5, aliasLen)));
    return result;
}

int ProtocolAdapter::parseTopicCreateResponse(const QByteArray &payload)
{
    if (payload.isEmpty()) return -1;
    return static_cast<unsigned char>(payload.at(0));
}

int ProtocolAdapter::parseTopicDeleteResponse(const QByteArray &payload)
{
    if (payload.isEmpty()) return -1;
    return static_cast<unsigned char>(payload.at(0));
}

int ProtocolAdapter::parseRuleSetResponse(const QByteArray &payload)
{
    if (payload.isEmpty()) return -1;
    return static_cast<unsigned char>(payload.at(0));
}
