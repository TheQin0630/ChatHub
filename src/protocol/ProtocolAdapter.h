#pragma once

#include <QByteArray>
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>

class ProtocolAdapter
{
public:
    enum MessageType {
        Subscribe = 1,
        Unsubscribe = 2,
        Publish = 3,
        SubscribeAck = 4,
        PublishAck = 5,
        LogQuery = 6,
        SubQuery = 7,
        LogListRequest = 8,
        LogListResponse = 9,
        TopicListRequest = 10,
        TopicListResponse = 11,
        PublishEx = 12,
        PubRec1 = 13,
        Deliver = 14,
        DeliverAck = 15,

        ConnectionListRequest = 16,
        ConnectionListResponse = 17,
        TopicSubscribersRequest = 18,
        TopicSubscribersResponse = 19,
        RuleSetRequest = 20,
        RuleSetResponse = 21,
        SubscribeReject = 22,
        PublishReject = 23,
        TopicCreateRequest = 24,
        TopicCreateResponse = 25,
        TopicDeleteRequest = 26,
        TopicDeleteResponse = 27,
        FdTopicRelationRequest = 28,
        FdTopicRelationResponse = 29
    };

    struct Frame {
        MessageType type = Publish;
        QString topic;
        QByteArray payload;
        int flags = 0;
        int qos = 0;
        bool retain = false;
        bool dup = false;
        int packetId = 0;

        // For reject messages (future protocol support)
        int rejectCode = 0;      // 0=success, 1=not_found, 2=denied, 3=invalid
        QString rejectReason;    // Human-readable reason
    };

    struct PageInfo {
        int requestId = 0;
        int totalItems = 0;
        int offset = 0;
        int returnedCount = 0;
        bool hasMore = false;
    };

    struct TopicSummary {
        QString topic;
        int subscriberCount = 0;
    };

    enum class ParseResult {
        Complete,
        Incomplete,
        Invalid
    };

    static constexpr int MaxTopicBytes = 64;
    static constexpr int MaxPayloadBytes = 2048;
    static constexpr int HeaderBytes = 4;
    static constexpr int PageRequestBytes = 7;
    static constexpr int PageResponseHeaderBytes = 9;
    static constexpr int PublishExHeaderBytes = 5;
    static constexpr int AckPayloadBytes = 3;

    static QByteArray pack(MessageType type, const QString &topic, const QByteArray &payload = {});
    static QByteArray packFrame(const Frame &frame);
    static QByteArray packPageRequest(int requestId, int offset, int limit, int order);
    static Frame makeExtendedPublish(const QString &topic, const QByteArray &payload, int qos, bool retain, int packetId, bool dup = false);
    static Frame makeDeliverAck(const QString &topic, int packetId);
    static QByteArray packRuleSetRequest(int op, unsigned char mask, int fd, const QString &topic);
    static QByteArray packFdTopicRelationRequest(int fd);
    static QByteArray packTopicCreateRequest(const QString &topic);
    static QByteArray packTopicDeleteRequest(const QString &topic);

    static ParseResult tryParse(QByteArray *buffer, Frame *frame, QString *error);
    static bool isTopicValid(const QString &topic, QString *error = nullptr);
    static bool isPayloadValid(const QByteArray &payload, QString *error = nullptr);
    static QByteArray makeChatPayload(const QString &nickname, const QString &message);
    static void parseChatPayload(const QByteArray &payload, QString *nickname, QString *message);
    static bool parsePageHeader(const QByteArray &payload, PageInfo *info);
    static QStringList parseLogPage(const QByteArray &payload, PageInfo *info);
    static QList<TopicSummary> parseTopicPage(const QByteArray &payload, PageInfo *info);
    static bool parseRejectFrame(const QByteArray &payload, int *rejectCode, QString *rejectReason);
    static QVariantList parseConnectionList(const QByteArray &payload);
    static QVariantList parseTopicSubscribers(const QByteArray &payload);
    static int parseTopicSubscribersStatus(const QByteArray &payload);
    static QVariantMap parseFdTopicRelation(const QByteArray &payload);
    static int parseTopicCreateResponse(const QByteArray &payload);
    static int parseTopicDeleteResponse(const QByteArray &payload);
    static int parseRuleSetResponse(const QByteArray &payload);

private:
    static int readU16(const QByteArray &data, int offset);
    static void writeU16(QByteArray *data, int offset, int value);
};
