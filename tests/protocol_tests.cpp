#include "../src/protocol/ProtocolAdapter.h"

#include <QCoreApplication>
#include <QDebug>
#include <QVariantMap>

static void require(bool condition, const char *message)
{
    if (!condition) {
        qCritical() << message;
        std::exit(1);
    }
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    const QByteArray payload = ProtocolAdapter::makeChatPayload(QStringLiteral("alice"), QStringLiteral("hello"));
    QByteArray stream = ProtocolAdapter::pack(ProtocolAdapter::Publish, QStringLiteral("room/general"), payload);
    ProtocolAdapter::Frame frame;
    QString error;
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected complete publish frame");
    require(stream.isEmpty(), "expected consumed stream");
    require(frame.type == ProtocolAdapter::Publish, "expected publish type");
    require(frame.topic == QStringLiteral("room/general"), "expected topic");

    QString user;
    QString text;
    ProtocolAdapter::parseChatPayload(frame.payload, &user, &text);
    require(user == QStringLiteral("alice"), "expected parsed user");
    require(text == QStringLiteral("hello"), "expected parsed message");

    ProtocolAdapter::Frame extended = ProtocolAdapter::makeExtendedPublish(QStringLiteral("room/general"), payload, 1, true, 42);
    stream = ProtocolAdapter::packFrame(extended);
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected complete extended frame");
    require(frame.type == ProtocolAdapter::PublishEx, "expected publish_ex type");
    require(frame.packetId == 42, "expected packet id");
    require(frame.qos == 1, "expected qos1");
    require(frame.retain, "expected retain flag");
    ProtocolAdapter::parseChatPayload(frame.payload, &user, &text);
    require(text == QStringLiteral("hello"), "expected extended payload");

    QByteArray partial = ProtocolAdapter::pack(ProtocolAdapter::Publish, QStringLiteral("room/general"), payload).left(3);
    require(ProtocolAdapter::tryParse(&partial, &frame, &error) == ProtocolAdapter::ParseResult::Incomplete,
            "expected incomplete frame");

    QByteArray pagePayload = ProtocolAdapter::packPageRequest(7, 20, 10, 1);
    require(pagePayload.size() == ProtocolAdapter::PageRequestBytes, "expected page request size");

    QByteArray topicResponse;
    topicResponse.resize(ProtocolAdapter::PageResponseHeaderBytes);
    topicResponse[0] = 0;
    topicResponse[1] = 7;
    topicResponse[2] = 0;
    topicResponse[3] = 1;
    topicResponse[4] = 0;
    topicResponse[5] = 0;
    topicResponse[6] = 0;
    topicResponse[7] = 1;
    topicResponse[8] = 0;
    const QByteArray topic = "room/general";
    topicResponse.append(static_cast<char>(topic.size()));
    topicResponse.append(topic);
    topicResponse.append('\0');
    topicResponse.append('\2');
    ProtocolAdapter::PageInfo info;
    const QList<ProtocolAdapter::TopicSummary> rows = ProtocolAdapter::parseTopicPage(topicResponse, &info);
    require(info.requestId == 7, "expected response id");
    require(rows.size() == 1, "expected one topic row");
    require(rows.first().topic == QStringLiteral("room/general"), "expected topic row name");
    require(rows.first().subscriberCount == 2, "expected subscriber count");

    QString validationError;
    require(!ProtocolAdapter::isTopicValid(QStringLiteral("bad topic"), &validationError),
            "expected invalid topic with whitespace");
    require(!ProtocolAdapter::isPayloadValid(QByteArray(3000, 'x'), &validationError),
            "expected oversized payload rejection");

    // Test DELIVER frame with QoS1
    ProtocolAdapter::Frame deliverFrame = ProtocolAdapter::makeExtendedPublish(
        QStringLiteral("room/test"), payload, 1, false, 100);
    deliverFrame.type = ProtocolAdapter::Deliver;
    stream = ProtocolAdapter::packFrame(deliverFrame);
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected complete deliver frame");
    require(frame.type == ProtocolAdapter::Deliver, "expected deliver type");
    require(frame.qos == 1, "expected deliver qos1");
    require(frame.packetId == 100, "expected deliver packet id");

    // Test DELIVER_ACK frame
    ProtocolAdapter::Frame ackFrame = ProtocolAdapter::makeDeliverAck(QStringLiteral("room/test"), 100);
    stream = ProtocolAdapter::packFrame(ackFrame);
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected complete deliver_ack frame");
    require(frame.type == ProtocolAdapter::DeliverAck, "expected deliver_ack type");
    require(frame.packetId == 100, "expected ack packet id");

    // Test LOG_LIST_RESP parsing
    QByteArray logResponse;
    logResponse.resize(ProtocolAdapter::PageResponseHeaderBytes);
    logResponse[0] = 0; logResponse[1] = 5;  // requestId = 5
    logResponse[2] = 0; logResponse[3] = 10; // totalItems = 10
    logResponse[4] = 0; logResponse[5] = 0;  // offset = 0
    logResponse[6] = 0; logResponse[7] = 2;  // returnedCount = 2
    logResponse[8] = 1;                      // hasMore = true
    const QByteArray log1 = "first log line";
    logResponse.append(static_cast<char>(log1.size()));
    logResponse.append(log1);
    const QByteArray log2 = "second log line";
    logResponse.append(static_cast<char>(log2.size()));
    logResponse.append(log2);
    ProtocolAdapter::PageInfo logInfo;
    const QStringList logs = ProtocolAdapter::parseLogPage(logResponse, &logInfo);
    require(logInfo.requestId == 5, "expected log request id");
    require(logInfo.totalItems == 10, "expected log total items");
    require(logInfo.hasMore, "expected log has more");
    require(logs.size() == 2, "expected two log lines");
    require(logs[0] == QStringLiteral("first log line"), "expected first log");
    require(logs[1] == QStringLiteral("second log line"), "expected second log");

    QByteArray extraLogResponse = logResponse;
    extraLogResponse[7] = 1; // returnedCount = 1, with two encoded rows present
    ProtocolAdapter::PageInfo extraLogInfo;
    const QStringList clippedLogs = ProtocolAdapter::parseLogPage(extraLogResponse, &extraLogInfo);
    require(clippedLogs.size() == 1, "expected log parser to honor returnedCount");

    QByteArray extraTopicResponse = topicResponse;
    extraTopicResponse[7] = 0; // returnedCount = 0, with one encoded row present
    ProtocolAdapter::PageInfo extraTopicInfo;
    const QList<ProtocolAdapter::TopicSummary> clippedTopics = ProtocolAdapter::parseTopicPage(extraTopicResponse, &extraTopicInfo);
    require(clippedTopics.isEmpty(), "expected topic parser to honor returnedCount");

    // Test reject frame parsing (future protocol)
    QByteArray rejectPayload;
    rejectPayload.append(static_cast<char>(2)); // rejectCode = 2 (denied)
    rejectPayload.append("topic not found");
    int rejectCode = 0;
    QString rejectReason;
    require(ProtocolAdapter::parseRejectFrame(rejectPayload, &rejectCode, &rejectReason),
            "expected valid reject frame");
    require(rejectCode == 2, "expected reject code 2");
    require(rejectReason == QStringLiteral("topic not found"), "expected reject reason");

    // Test SubscribeReject frame (future protocol - reserved enum value)
    ProtocolAdapter::Frame rejectFrame;
    rejectFrame.type = ProtocolAdapter::SubscribeReject;
    rejectFrame.topic = QStringLiteral("forbidden/topic");
    rejectFrame.payload = rejectPayload;
    stream = ProtocolAdapter::packFrame(rejectFrame);
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected complete subscribe_reject frame");
    require(frame.type == ProtocolAdapter::SubscribeReject, "expected subscribe_reject type");
    require(frame.rejectCode == 2, "expected parsed reject code");
    require(frame.rejectReason == QStringLiteral("topic not found"), "expected parsed reject reason");

    // Test PublishEx with retain flag
    ProtocolAdapter::Frame retainedFrame = ProtocolAdapter::makeExtendedPublish(
        QStringLiteral("room/announce"), payload, 1, true, 200);
    stream = ProtocolAdapter::packFrame(retainedFrame);
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected complete retained frame");
    require(frame.retain, "expected retain flag set");
    require(frame.qos == 1, "expected qos 1 for retained");
    require(frame.packetId == 200, "expected retained packet id");

    // Test empty topic validation
    require(!ProtocolAdapter::isTopicValid(QStringLiteral(""), &validationError),
            "expected empty topic rejection");
    require(!ProtocolAdapter::isTopicValid(QStringLiteral("  "), &validationError),
            "expected whitespace-only topic rejection");

    // Test topic with tabs/newlines
    require(!ProtocolAdapter::isTopicValid(QStringLiteral("room\ttopic"), &validationError),
            "expected topic with tab rejection");
    require(!ProtocolAdapter::isTopicValid(QStringLiteral("room\ntopic"), &validationError),
            "expected topic with newline rejection");

    QByteArray rulePayload = ProtocolAdapter::packRuleSetRequest(1, 0x0c, 0x01020304, QStringLiteral("room/general"));
    require(rulePayload.size() == 6, "expected rule request size");
    require(static_cast<unsigned char>(rulePayload.at(0)) == 1, "expected rule add op");
    require(static_cast<unsigned char>(rulePayload.at(1)) == 0x0c, "expected rule mask");
    require(static_cast<unsigned char>(rulePayload.at(2)) == 0x01, "expected fd byte 0");
    require(static_cast<unsigned char>(rulePayload.at(3)) == 0x02, "expected fd byte 1");
    require(static_cast<unsigned char>(rulePayload.at(4)) == 0x03, "expected fd byte 2");
    require(static_cast<unsigned char>(rulePayload.at(5)) == 0x04, "expected fd byte 3");

    QByteArray connPayload;
    connPayload.append('\0');
    connPayload.append('\1');
    connPayload.append('\0');
    connPayload.append('\0');
    connPayload.append('\0');
    connPayload.append('\7');
    connPayload.append('\177');
    connPayload.append('\0');
    connPayload.append('\0');
    connPayload.append('\1');
    connPayload.append('\x30');
    connPayload.append('\x39');
    connPayload.append('\5');
    connPayload.append("alice");
    const QVariantList connections = ProtocolAdapter::parseConnectionList(connPayload);
    require(connections.size() == 1, "expected one connection");
    require(connections.first().toMap().value(QStringLiteral("fd")).toInt() == 7, "expected parsed fd");
    require(connections.first().toMap().value(QStringLiteral("ip")).toString() == QStringLiteral("127.0.0.1"),
            "expected standard loopback ip formatting");
    require(connections.first().toMap().value(QStringLiteral("port")).toInt() == 12345, "expected parsed port");
    require(connections.first().toMap().value(QStringLiteral("alias")).toString() == QStringLiteral("alice"), "expected connection alias");

    QByteArray subsPayload;
    subsPayload.append('\0'); // TOPIC_SUBS_STATUS_OK
    subsPayload.append('\0');
    subsPayload.append('\1');
    subsPayload.append(connPayload.mid(2));
    require(ProtocolAdapter::parseTopicSubscribersStatus(subsPayload) == 0, "expected topic subscribers ok status");
    const QVariantList subscribers = ProtocolAdapter::parseTopicSubscribers(subsPayload);
    require(subscribers.size() == 1, "expected one topic subscriber");
    require(subscribers.first().toMap().value(QStringLiteral("fd")).toInt() == 7, "expected subscriber fd");
    require(subscribers.first().toMap().value(QStringLiteral("alias")).toString() == QStringLiteral("alice"), "expected subscriber alias");

    QByteArray missingSubsPayload;
    missingSubsPayload.append('\1'); // TOPIC_SUBS_STATUS_TOPIC_NOT_FOUND
    missingSubsPayload.append('\0');
    missingSubsPayload.append('\0');
    require(ProtocolAdapter::parseTopicSubscribersStatus(missingSubsPayload) == 1, "expected topic not found status");
    require(ProtocolAdapter::parseTopicSubscribers(missingSubsPayload).isEmpty(), "expected no subscribers for missing topic");

    QByteArray relationRequest = ProtocolAdapter::packFdTopicRelationRequest(0x01020304);
    require(relationRequest.size() == 4, "expected relation request size");
    require(static_cast<unsigned char>(relationRequest.at(0)) == 0x01, "expected relation fd byte 0");
    require(static_cast<unsigned char>(relationRequest.at(3)) == 0x04, "expected relation fd byte 3");

    QByteArray relationPayload;
    relationPayload.append('\0'); // REL_STATUS_OK
    relationPayload.append('\0');
    relationPayload.append('\0');
    relationPayload.append('\0');
    relationPayload.append('\7');
    relationPayload.append('\5'); // REL_SUBSCRIBED | REL_DENY_RECV
    relationPayload.append('\5');
    relationPayload.append("alice");
    const QVariantMap relation = ProtocolAdapter::parseFdTopicRelation(relationPayload);
    require(relation.value(QStringLiteral("status")).toInt() == 0, "expected relation status ok");
    require(relation.value(QStringLiteral("fd")).toInt() == 7, "expected relation fd");
    require(relation.value(QStringLiteral("mask")).toInt() == 5, "expected relation mask");
    require(relation.value(QStringLiteral("alias")).toString() == QStringLiteral("alice"), "expected relation alias");

    const QByteArray aliasRequest = ProtocolAdapter::packAliasSetRequest(QStringLiteral("alice"));
    require(aliasRequest == QByteArray("\x05" "alice"), "expected alias request payload");
    require(ProtocolAdapter::parseAliasPayload(aliasRequest) == QStringLiteral("alice"), "expected alias response parsing");

    QByteArray forwardedPayload;
    forwardedPayload.append('\0');
    forwardedPayload.append(static_cast<char>(payload.size()));
    forwardedPayload.append(payload);
    forwardedPayload.append('\5');
    forwardedPayload.append("alice");
    stream = ProtocolAdapter::pack(ProtocolAdapter::Publish, QStringLiteral("room/general"), forwardedPayload);
    require(ProtocolAdapter::tryParse(&stream, &frame, &error) == ProtocolAdapter::ParseResult::Complete,
            "expected forwarded publish frame");
    require(frame.alias == QStringLiteral("alice"), "expected forwarded publish alias");
    ProtocolAdapter::parseChatPayload(frame.payload, &user, &text);
    require(text == QStringLiteral("hello"), "expected forwarded business payload");

    qDebug() << "All protocol tests passed!";
    return 0;
}
