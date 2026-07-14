#include "ChatController.h"

#include <QTime>
#include <QVariantMap>

ChatController::ChatController(QObject *parent)
    : QObject(parent)
{
    connect(&m_network, &NetworkClient::connected, this, [this]() {
        setBusy(false);
        setStatusText(QStringLiteral("Connected"));
        appendLog(QStringLiteral("INFO"), QStringLiteral("connected to server"));
        emit connectedChanged();
        if (!m_network.sendFrame(ProtocolAdapter::AliasSetRequest, QString(),
                                 ProtocolAdapter::packAliasSetRequest(m_nickname))) {
            appendLog(QStringLiteral("ERROR"), QStringLiteral("failed to set connection alias"));
        }
        requestSelfConnection();
    });
    connect(&m_network, &NetworkClient::disconnected, this, [this]() {
        setBusy(false);
        setStatusText(QStringLiteral("Disconnected"));
        resetSessionState(QStringLiteral("connection closed"));
        appendLog(QStringLiteral("WARN"), QStringLiteral("connection closed"));
        emit connectedChanged();
    });
    connect(&m_network, &NetworkClient::networkError, this, [this](const QString &message) {
        setBusy(false);
        setStatusText(QStringLiteral("Network error"));
        appendLog(QStringLiteral("ERROR"), message);
        emit userMessage(message);
    });
    connect(&m_network, &NetworkClient::parseError, this, [this](const QString &message) {
        appendLog(QStringLiteral("ERROR"), QStringLiteral("parse failed: %1").arg(message));
        emit userMessage(QStringLiteral("received invalid server frame"));
    });
    connect(&m_network, &NetworkClient::frameReceived, this, &ChatController::handleFrame);
}

ChatController::~ChatController()
{
    disconnect(&m_network, nullptr, this, nullptr);
}

bool ChatController::connected() const
{
    return m_network.isConnected();
}

bool ChatController::busy() const
{
    return m_busy;
}

QString ChatController::statusText() const
{
    return m_statusText;
}

void ChatController::connectToServer(const QString &host, int port, const QString &nickname)
{
    if (host.trimmed().isEmpty() || port <= 0 || port > 65535) {
        emit userMessage(QStringLiteral("invalid host or port"));
        return;
    }
    m_nickname = nickname.trimmed().isEmpty() ? QStringLiteral("guest") : nickname.trimmed();
    if (m_nickname.toUtf8().size() > ProtocolAdapter::MaxAliasBytes) {
        emit userMessage(QStringLiteral("Nickname must be at most %1 UTF-8 bytes").arg(ProtocolAdapter::MaxAliasBytes));
        return;
    }
    setBusy(true);
    setStatusText(QStringLiteral("Connecting"));
    appendLog(QStringLiteral("INFO"), QStringLiteral("connect %1:%2 as %3").arg(host.trimmed()).arg(port).arg(m_nickname));
    m_network.connectToHost(host.trimmed(), static_cast<quint16>(port));
}

void ChatController::requestSelfConnection()
{
    if (!m_network.sendFrame(ProtocolAdapter::SelfConnectionRequest, QString())) {
        emit userMessage(QStringLiteral("failed to request self connection information"));
    }
}

void ChatController::setConnectionAlias(const QString &alias)
{
    const QString normalized = alias.trimmed();
    if (normalized.toUtf8().size() > ProtocolAdapter::MaxAliasBytes) {
        emit userMessage(QStringLiteral("Alias must be at most %1 UTF-8 bytes").arg(ProtocolAdapter::MaxAliasBytes));
        return;
    }
    if (!connected()) {
        emit userMessage(QStringLiteral("Connect before changing the alias"));
        return;
    }
    if (!m_network.sendFrame(ProtocolAdapter::AliasSetRequest, QString(),
                             ProtocolAdapter::packAliasSetRequest(normalized))) {
        emit userMessage(QStringLiteral("failed to send alias update"));
    }
}

void ChatController::unsubscribeConnection(const QString &topic, int fd)
{
    if (!connected() || fd <= 0) {
        emit userMessage(QStringLiteral("invalid forced unsubscribe request"));
        return;
    }
    if (!m_network.sendFrame(ProtocolAdapter::UnsubscribeFdRequest, topic,
                             ProtocolAdapter::packUnsubscribeFdRequest(fd))) {
        emit userMessage(QStringLiteral("failed to send forced unsubscribe request"));
    }
}

void ChatController::disconnectFromServer()
{
    m_network.disconnectFromHost();
}

void ChatController::subscribeTopic(const QString &topic)
{
    QString error;
    const QString normalized = topic.trimmed();
    if (!ProtocolAdapter::isTopicValid(normalized, &error)) {
        emit userMessage(error);
        return;
    }
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    if (m_network.sendFrame(ProtocolAdapter::Subscribe, normalized)) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("subscribe %1").arg(normalized));
    } else {
        emit userMessage(QStringLiteral("failed to write subscribe request"));
    }
}

void ChatController::unsubscribeTopic(const QString &topic)
{
    const QString normalized = topic.trimmed();
    if (!m_channels.contains(normalized)) {
        emit userMessage(QStringLiteral("channel does not exist"));
        return;
    }
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    if (m_network.sendFrame(ProtocolAdapter::Unsubscribe, normalized)) {
        m_channels.remove(normalized);
        appendLog(QStringLiteral("SEND"), QStringLiteral("unsubscribe %1; server has no unsubscribe ack").arg(normalized));
        emit channelRemoved(normalized);
    }
}

bool ChatController::publishMessage(const QString &topic, const QString &message)
{
    return publishMessageAdvanced(topic, message, false, false);
}

bool ChatController::publishMessageAdvanced(const QString &topic, const QString &message, bool reliable, bool retain)
{
    const QString normalized = topic.trimmed();
    QString error;
    if (!ProtocolAdapter::isTopicValid(normalized, &error)) {
        emit userMessage(error);
        return false;
    }
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return false;
    }
    if (!m_channels.contains(normalized)) {
        emit userMessage(QStringLiteral("subscribe this channel first"));
        return false;
    }

    const QString body = message.trimmed();
    const QByteArray payload = ProtocolAdapter::makeChatPayload(m_nickname, body);
    if (!ProtocolAdapter::isPayloadValid(payload, &error)) {
        emit userMessage(error);
        return false;
    }

    if (reliable || retain) {
        const int packetId = nextPacketId();
        const int clientMessageId = m_nextClientMessageId++;
        const ProtocolAdapter::Frame frame = ProtocolAdapter::makeExtendedPublish(normalized, payload, 1, retain, packetId);
        if (m_network.sendFrame(frame)) {
            const QDateTime timestamp = QDateTime::currentDateTime();
            m_pendingPublishes.enqueue({normalized, body, timestamp, packetId, clientMessageId, true});
            emit outgoingMessageQueued(normalized, m_nickname, body, timestamp.time().toString(QStringLiteral("HH:mm")), clientMessageId);
            appendLog(QStringLiteral("SEND"), QStringLiteral("publish_ex %1 packet=%2 retain=%3 bytes=%4")
                      .arg(normalized).arg(packetId).arg(retain ? 1 : 0).arg(payload.size()));
            return true;
        }
        emit userMessage(QStringLiteral("failed to write message to socket"));
        return false;
    }

    if (m_network.sendFrame(ProtocolAdapter::Publish, normalized, payload)) {
        const int clientMessageId = m_nextClientMessageId++;
        const QDateTime timestamp = QDateTime::currentDateTime();
        m_pendingPublishes.enqueue({normalized, body, timestamp, 0, clientMessageId, false});
        emit outgoingMessageQueued(normalized, m_nickname, body, timestamp.time().toString(QStringLiteral("HH:mm")), clientMessageId);
        appendLog(QStringLiteral("SEND"), QStringLiteral("publish %1 bytes=%2").arg(normalized).arg(payload.size()));
        return true;
    }
    emit userMessage(QStringLiteral("failed to write message to socket"));
    return false;
}

bool ChatController::requestServerLogs(int offset, int limit, bool newestFirst)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return false;
    }
    const int requestId = nextRequestId();
    const QByteArray payload = ProtocolAdapter::packPageRequest(requestId, qMax(0, offset), qBound(1, limit, 50), newestFirst ? 1 : 0);
    if (!m_network.sendFrame(ProtocolAdapter::LogListRequest, QString(), payload)) {
        emit userMessage(QStringLiteral("failed to request server logs"));
        return false;
    }
    appendLog(QStringLiteral("SEND"), QStringLiteral("query logs offset=%1 limit=%2").arg(qMax(0, offset)).arg(qBound(1, limit, 50)));
    return true;
}

bool ChatController::requestServerTopics(int offset, int limit, bool includeEmpty)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return false;
    }
    const int requestId = nextRequestId();
    const QByteArray payload = ProtocolAdapter::packPageRequest(requestId, qMax(0, offset), qBound(1, limit, 50), includeEmpty ? 1 : 0);
    if (!m_network.sendFrame(ProtocolAdapter::TopicListRequest, QString(), payload)) {
        emit userMessage(QStringLiteral("failed to request server topics"));
        return false;
    }
    appendLog(QStringLiteral("SEND"), QStringLiteral("query topics offset=%1 limit=%2").arg(qMax(0, offset)).arg(qBound(1, limit, 50)));
    return true;
}

void ChatController::requestServerSnapshot()
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    m_network.sendFrame(ProtocolAdapter::LogQuery, QString());
    m_network.sendFrame(ProtocolAdapter::SubQuery, QString());
}

void ChatController::requestConnectionList()
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    if (m_network.sendFrame(ProtocolAdapter::ConnectionListRequest, QString())) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("query connection list"));
    }
}

void ChatController::requestTopicSubscribers(const QString &topic)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    const QString normalized = topic.trimmed();
    if (m_network.sendFrame(ProtocolAdapter::TopicSubscribersRequest, normalized)) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("query subscribers for %1").arg(normalized));
    }
}

void ChatController::requestFdTopicRelation(const QString &topic, int fd)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    const QString normalized = topic.trimmed();
    QString error;
    if (!ProtocolAdapter::isTopicValid(normalized, &error)) {
        emit userMessage(error);
        return;
    }
    if (fd <= 0) {
        emit userMessage(QStringLiteral("select a valid connection fd"));
        return;
    }
    const QByteArray payload = ProtocolAdapter::packFdTopicRelationRequest(fd);
    if (m_network.sendFrame(ProtocolAdapter::FdTopicRelationRequest, normalized, payload)) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("query relation fd=%1 topic=%2").arg(fd).arg(normalized));
    }
}

void ChatController::createTopic(const QString &topic)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    QString error;
    const QString normalized = topic.trimmed();
    if (!ProtocolAdapter::isTopicValid(normalized, &error)) {
        emit userMessage(error);
        return;
    }
    const QByteArray payload = ProtocolAdapter::packTopicCreateRequest(normalized);
    if (m_network.sendFrame(ProtocolAdapter::TopicCreateRequest, normalized, payload)) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("create topic %1").arg(normalized));
    }
}

void ChatController::deleteTopic(const QString &topic)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    const QString normalized = topic.trimmed();
    const QByteArray payload = ProtocolAdapter::packTopicDeleteRequest(normalized);
    if (m_network.sendFrame(ProtocolAdapter::TopicDeleteRequest, normalized, payload)) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("delete topic %1").arg(normalized));
    }
}

void ChatController::setRule(const QString &topic, int ruleMask, bool add)
{
    Q_UNUSED(topic)
    Q_UNUSED(ruleMask)
    Q_UNUSED(add)
    emit userMessage(QStringLiteral("select a connection before setting a rule"));
}

void ChatController::setConnectionRule(const QString &topic, int fd, int ruleMask, bool add)
{
    if (!connected()) {
        emit userMessage(QStringLiteral("connect first"));
        return;
    }
    const QString normalized = topic.trimmed();
    QString error;
    if (!ProtocolAdapter::isTopicValid(normalized, &error)) {
        emit userMessage(error);
        return;
    }
    if (fd <= 0) {
        emit userMessage(QStringLiteral("select a valid connection fd"));
        return;
    }
    if ((ruleMask & ~0x0e) != 0 || ruleMask == 0) {
        emit userMessage(QStringLiteral("select at least one rule type"));
        return;
    }
    // UI/关系查询位：sub=0x02, recv=0x04, pub=0x08。
    // 服务端规则设置位：sub=0x01, recv=0x02, pub=0x04。
    unsigned char serverMask = 0;
    if (ruleMask & 0x02) serverMask |= 0x01;
    if (ruleMask & 0x04) serverMask |= 0x02;
    if (ruleMask & 0x08) serverMask |= 0x04;
    const int op = add ? 1 : 2; // RULE_OP_ADD=1, RULE_OP_DEL=2
    const QByteArray payload = ProtocolAdapter::packRuleSetRequest(op, serverMask, fd, normalized);
    if (m_network.sendFrame(ProtocolAdapter::RuleSetRequest, normalized, payload)) {
        appendLog(QStringLiteral("SEND"), QStringLiteral("%1 rule for fd=%2 topic=%3 mask=%4")
                  .arg(add ? "add" : "del").arg(fd).arg(normalized).arg(ruleMask));
    }
}

void ChatController::addForwardRule(const QString &sourceTopic, const QString &targetTopic)
{
    Q_UNUSED(sourceTopic)
    Q_UNUSED(targetTopic)
    emit userMessage(QStringLiteral("forward rule management not yet implemented in this client"));
}

void ChatController::deleteForwardRule(const QString &sourceTopic, const QString &targetTopic)
{
    Q_UNUSED(sourceTopic)
    Q_UNUSED(targetTopic)
    emit userMessage(QStringLiteral("forward rule management not yet implemented in this client"));
}

void ChatController::setBusy(bool busy)
{
    if (m_busy == busy) return;
    m_busy = busy;
    emit busyChanged();
}

void ChatController::setStatusText(const QString &statusText)
{
    if (m_statusText == statusText) return;
    m_statusText = statusText;
    emit statusTextChanged();
}

void ChatController::appendLog(const QString &level, const QString &message)
{
    emit logAdded(QTime::currentTime().toString(QStringLiteral("HH:mm:ss")), level, message);
}

void ChatController::handleFrame(const ProtocolAdapter::Frame &frame)
{
    switch (frame.type) {
    case ProtocolAdapter::SubscribeAck:
        m_channels.insert(frame.topic);
        appendLog(QStringLiteral("ACK"), QStringLiteral("suback %1").arg(frame.topic));
        emit channelConfirmed(frame.topic);
        break;
    case ProtocolAdapter::PublishAck:
        appendLog(QStringLiteral("ACK"), QStringLiteral("puback %1").arg(frame.topic));
        if (!confirmPendingPublish(frame)) {
            appendLog(QStringLiteral("WARN"), QStringLiteral("puback had no matching pending publish: %1").arg(frame.topic));
        }
        break;
    case ProtocolAdapter::PubRec1:
        appendLog(QStringLiteral("ACK"), QStringLiteral("pubrec1 packet=%1").arg(frame.packetId));
        if (!confirmPendingPublish(frame)) {
            appendLog(QStringLiteral("WARN"), QStringLiteral("pubrec1 had no matching packet: %1").arg(frame.packetId));
        }
        break;
    case ProtocolAdapter::Publish:
    case ProtocolAdapter::Deliver: {
        QString user;
        QString text;
        ProtocolAdapter::parseChatPayload(frame.payload, &user, &text);
        if (!frame.alias.isEmpty()) user = frame.alias;
        if (!m_channels.contains(frame.topic)) {
            m_channels.insert(frame.topic);
            emit channelConfirmed(frame.topic);
            appendLog(QStringLiteral("WARN"), QStringLiteral("auto-added channel from incoming message: %1").arg(frame.topic));
        }
        const bool isRetained = frame.type == ProtocolAdapter::Deliver && frame.retain;
        emit incomingMessage(frame.topic, user, text, false, isRetained, isRetained ? QStringLiteral("retained") : QString(), QTime::currentTime().toString(QStringLiteral("HH:mm")));
        if (frame.type == ProtocolAdapter::Deliver && frame.qos == 1 && frame.packetId > 0) {
            m_network.sendFrame(ProtocolAdapter::makeDeliverAck(frame.topic, frame.packetId));
            appendLog(QStringLiteral("SEND"), QStringLiteral("deliver_ack packet=%1").arg(frame.packetId));
        }
        break;
    }
    case ProtocolAdapter::LogQuery:
    {
        const QString body = QString::fromUtf8(frame.payload);
        QStringList rows = body.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        if (rows.size() > 8) {
            rows = rows.mid(0, 8);
        }
        if (rows.isEmpty() && !body.isEmpty()) {
            rows.append(body.left(180));
        }
        emit serverLogsReceived(rows, rows.size(), 0, false);
        emit serverSnapshotReceived(QStringLiteral("Server log snapshot"), QString());
        break;
    }
    case ProtocolAdapter::SubQuery:
        emit serverSnapshotReceived(QStringLiteral("Subscription snapshot"), QString());
        break;
    case ProtocolAdapter::LogListResponse: {
        ProtocolAdapter::PageInfo info;
        const QStringList rows = ProtocolAdapter::parseLogPage(frame.payload, &info);
        emit serverLogsReceived(rows, info.totalItems, info.offset, info.hasMore);
        break;
    }
    case ProtocolAdapter::TopicListResponse: {
        ProtocolAdapter::PageInfo info;
        const QList<ProtocolAdapter::TopicSummary> topics = ProtocolAdapter::parseTopicPage(frame.payload, &info);
        QVariantList rows;
        for (const auto &topic : topics) {
            QVariantMap row;
            row.insert(QStringLiteral("topic"), topic.topic);
            row.insert(QStringLiteral("subscribers"), topic.subscriberCount);
            rows.append(row);
        }
        emit serverTopicsReceived(rows, info.totalItems, info.offset, info.hasMore);
        break;
    }
    case ProtocolAdapter::SubscribeReject:
        appendLog(QStringLiteral("ERROR"), QStringLiteral("subscribe rejected: %1 (code=%2)").arg(frame.rejectReason).arg(frame.rejectCode));
        if (frame.rejectCode == 2) {
            m_pendingSubscribeAfterCreate.insert(frame.topic);
            const QByteArray payload = ProtocolAdapter::packTopicCreateRequest(frame.topic);
            if (m_network.sendFrame(ProtocolAdapter::TopicCreateRequest, frame.topic, payload)) {
                appendLog(QStringLiteral("SEND"), QStringLiteral("create missing topic %1").arg(frame.topic));
            } else {
                emit userMessage(QStringLiteral("failed to write topic create request"));
                emit channelRemoved(frame.topic);
            }
        } else {
            emit userMessage(QStringLiteral("Subscribe rejected: %1").arg(frame.rejectReason));
            emit channelRemoved(frame.topic);
        }
        break;
    case ProtocolAdapter::PublishReject:
        appendLog(QStringLiteral("ERROR"), QStringLiteral("publish rejected: %1 (code=%2)").arg(frame.rejectReason).arg(frame.rejectCode));
        if (!failPendingPublish(frame, frame.rejectReason)) {
            appendLog(QStringLiteral("WARN"), QStringLiteral("publish reject had no matching pending publish: %1").arg(frame.topic));
        }
        emit userMessage(QStringLiteral("Publish rejected: %1").arg(frame.rejectReason));
        break;
    case ProtocolAdapter::ConnectionListResponse: {
        const QVariantList connections = ProtocolAdapter::parseConnectionList(frame.payload);
        emit serverConnectionsReceived(connections);
        appendLog(QStringLiteral("RECV"), QStringLiteral("connection list: %1 entries").arg(connections.size()));
        break;
    }
    case ProtocolAdapter::SelfConnectionResponse: {
        const QVariantMap connection = ProtocolAdapter::parseSelfConnection(frame.payload);
        if (connection.isEmpty()) {
            appendLog(QStringLiteral("ERROR"), QStringLiteral("invalid self connection response"));
        } else {
            emit selfConnectionReceived(connection);
        }
        break;
    }
    case ProtocolAdapter::AliasSetResponse: {
        const QString alias = ProtocolAdapter::parseAliasPayload(frame.payload);
        if (frame.payload.isEmpty() || !alias.isNull()) {
            m_nickname = alias;
            emit aliasConfirmed(alias);
            appendLog(QStringLiteral("ACK"), QStringLiteral("alias confirmed: %1").arg(alias));
        } else {
            appendLog(QStringLiteral("ERROR"), QStringLiteral("invalid alias response"));
        }
        break;
    }
    case ProtocolAdapter::UnsubscribeFdResponse: {
        const QVariantMap result = ProtocolAdapter::parseUnsubscribeFdResponse(frame.payload);
        if (result.isEmpty()) {
            appendLog(QStringLiteral("ERROR"), QStringLiteral("invalid forced unsubscribe response"));
        } else {
            emit connectionUnsubscribed(frame.topic, result.value(QStringLiteral("fd")).toInt(),
                                        result.value(QStringLiteral("alias")).toString());
        }
        break;
    }
    case ProtocolAdapter::UnsubscribeFdNotify:
        if (m_channels.remove(frame.topic)) {
            emit channelRemoved(frame.topic);
        }
        emit userMessage(QStringLiteral("Server removed your subscription to %1").arg(frame.topic));
        break;
    case ProtocolAdapter::TopicSubscribersResponse: {
        const QVariantList subscribers = ProtocolAdapter::parseTopicSubscribers(frame.payload);
        const int status = ProtocolAdapter::parseTopicSubscribersStatus(frame.payload);
        emit topicSubscribersReceived(frame.topic, subscribers);
        emit topicSubscribersStateReceived(frame.topic, status);
        appendLog(QStringLiteral("RECV"), QStringLiteral("topic subscribers for %1: status=%2 entries=%3").arg(frame.topic).arg(status).arg(subscribers.size()));
        break;
    }
    case ProtocolAdapter::FdTopicRelationResponse: {
        const QVariantMap relation = ProtocolAdapter::parseFdTopicRelation(frame.payload);
        const int status = relation.value(QStringLiteral("status")).toInt();
        const int fd = relation.value(QStringLiteral("fd")).toInt();
        const int mask = relation.value(QStringLiteral("mask")).toInt();
        emit fdTopicRelationReceived(frame.topic, fd, status, mask);
        appendLog(QStringLiteral("RECV"), QStringLiteral("relation fd=%1 topic=%2 status=%3 mask=%4")
                  .arg(fd).arg(frame.topic).arg(status).arg(mask));
        break;
    }
    case ProtocolAdapter::TopicCreateResponse: {
        const int status = ProtocolAdapter::parseTopicCreateResponse(frame.payload);
        emit topicCreated(frame.topic, status);
        m_pendingSubscribeAfterCreate.remove(frame.topic);
        if (status == 0) {
            appendLog(QStringLiteral("INFO"), QStringLiteral("topic created: %1").arg(frame.topic));
        } else if (status == 1) {
            appendLog(QStringLiteral("WARN"), QStringLiteral("topic already exists: %1").arg(frame.topic));
        } else {
            appendLog(QStringLiteral("ERROR"), QStringLiteral("topic create failed: %1 status=%2").arg(frame.topic).arg(status));
            emit userMessage(QStringLiteral("Failed to create topic: %1").arg(frame.topic));
        }
        if (status == 0 || status == 1) {
            if (m_network.sendFrame(ProtocolAdapter::Subscribe, frame.topic)) {
                appendLog(QStringLiteral("SEND"), QStringLiteral("subscribe %1").arg(frame.topic));
            }
        }
        break;
    }
    case ProtocolAdapter::TopicDeleteResponse: {
        const int status = ProtocolAdapter::parseTopicDeleteResponse(frame.payload);
        emit topicDeleted(frame.topic, status);
        if (status == 0) {
            appendLog(QStringLiteral("INFO"), QStringLiteral("topic deleted: %1").arg(frame.topic));
        } else {
            appendLog(QStringLiteral("WARN"), QStringLiteral("topic not found: %1").arg(frame.topic));
            emit userMessage(QStringLiteral("Topic not found: %1").arg(frame.topic));
        }
        break;
    }
    case ProtocolAdapter::RuleSetResponse: {
        const int status = ProtocolAdapter::parseRuleSetResponse(frame.payload);
        emit ruleSetResult(status);
        if (status == 0) {
            appendLog(QStringLiteral("INFO"), QStringLiteral("rule set successfully"));
            emit userMessage(QStringLiteral("Rule operation succeeded"));
        } else {
            appendLog(QStringLiteral("ERROR"), QStringLiteral("rule set failed: status=%1").arg(status));
            emit userMessage(QStringLiteral("Rule operation failed (status=%1)").arg(status));
        }
        break;
    }
    default:
        appendLog(QStringLiteral("WARN"), QStringLiteral("unexpected message type %1").arg(static_cast<int>(frame.type)));
        break;
    }
}

void ChatController::resetSessionState(const QString &reason)
{
    failAllPendingPublishes(reason);
    m_pendingSubscribeAfterCreate.clear();

    const QList<QString> topics = m_channels.values();
    m_channels.clear();
    for (const QString &topic : topics) {
        emit channelRemoved(topic);
    }
}

void ChatController::failAllPendingPublishes(const QString &reason)
{
    while (!m_pendingPublishes.isEmpty()) {
        const PendingPublish item = m_pendingPublishes.dequeue();
        emit outgoingMessageFailed(item.clientMessageId, reason);
    }
}

bool ChatController::confirmPendingPublish(const ProtocolAdapter::Frame &frame)
{
    for (int i = 0; i < m_pendingPublishes.size(); ++i) {
        const PendingPublish &candidate = m_pendingPublishes.at(i);
        const bool packetMatches = frame.packetId > 0 && candidate.packetId == frame.packetId;
        const bool topicMatches = frame.packetId == 0 && !candidate.extended
                && !frame.topic.isEmpty() && candidate.topic == frame.topic;
        if (!packetMatches && !topicMatches) {
            continue;
        }

        const PendingPublish item = m_pendingPublishes.takeAt(i);
        emit publishAck(item.topic);
        emit outgoingMessageConfirmed(item.clientMessageId);
        return true;
    }
    return false;
}

bool ChatController::failPendingPublish(const ProtocolAdapter::Frame &frame, const QString &reason)
{
    for (int i = 0; i < m_pendingPublishes.size(); ++i) {
        const PendingPublish &candidate = m_pendingPublishes.at(i);
        const bool packetMatches = frame.packetId > 0 && candidate.packetId == frame.packetId;
        const bool topicMatches = !frame.topic.isEmpty() && candidate.topic == frame.topic;
        const bool onlyPendingFallback = frame.packetId == 0 && frame.topic.isEmpty() && m_pendingPublishes.size() == 1;
        if (!packetMatches && !topicMatches && !onlyPendingFallback) {
            continue;
        }

        const PendingPublish item = m_pendingPublishes.takeAt(i);
        emit outgoingMessageFailed(item.clientMessageId, reason);
        return true;
    }
    return false;
}

int ChatController::nextPacketId()
{
    const int value = m_nextPacketId++;
    if (m_nextPacketId > 65535) {
        m_nextPacketId = 1;
    }
    return value;
}

int ChatController::nextRequestId()
{
    const int value = m_nextRequestId++;
    if (m_nextRequestId > 65535) {
        m_nextRequestId = 1;
    }
    return value;
}
