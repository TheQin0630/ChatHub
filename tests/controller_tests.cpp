#include "../src/controller/ChatController.h"

#include <QCoreApplication>
#include <QDebug>
#include <QElapsedTimer>
#include <QEventLoop>
#include <QHostAddress>
#include <QMap>
#include <QTcpServer>
#include <QTcpSocket>
#include <QThread>
#include <QVector>

#include <functional>

static void require(bool condition, const char *message)
{
    if (!condition) {
        qCritical() << message;
        std::exit(1);
    }
}

static bool waitUntil(const std::function<bool()> &predicate, int timeoutMs = 1500)
{
    QElapsedTimer timer;
    timer.start();
    while (timer.elapsed() < timeoutMs) {
        QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
        if (predicate()) {
            return true;
        }
        QThread::msleep(1);
    }
    QCoreApplication::processEvents(QEventLoop::AllEvents, 10);
    return predicate();
}

static QTcpSocket *connectController(ChatController *controller, QTcpServer *server)
{
    controller->connectToServer(QStringLiteral("127.0.0.1"), server->serverPort(), QStringLiteral("tester"));
    require(waitUntil([&]() { return server->hasPendingConnections(); }), "expected controller connection");
    QTcpSocket *socket = server->nextPendingConnection();
    require(socket != nullptr, "expected accepted socket");
    require(waitUntil([&]() { return controller->connected(); }), "expected controller connected state");
    return socket;
}

static void sendFrame(QTcpSocket *socket, ProtocolAdapter::MessageType type, const QString &topic, const QByteArray &payload = {})
{
    socket->write(ProtocolAdapter::pack(type, topic, payload));
    socket->flush();
    socket->waitForBytesWritten(250);
}

static void acknowledgeSubscription(QTcpSocket *socket, const QString &topic)
{
    sendFrame(socket, ProtocolAdapter::SubscribeAck, topic);
}

static void testDisconnectClearsChannelsAndPending()
{
    QTcpServer server;
    require(server.listen(QHostAddress::LocalHost, 0), "expected server listen");

    ChatController controller;
    QStringList confirmedChannels;
    QStringList removedChannels;
    QVector<int> failedMessages;

    QObject::connect(&controller, &ChatController::channelConfirmed, [&](const QString &topic) {
        confirmedChannels.append(topic);
    });
    QObject::connect(&controller, &ChatController::channelRemoved, [&](const QString &topic) {
        removedChannels.append(topic);
    });
    QObject::connect(&controller, &ChatController::outgoingMessageFailed, [&](int clientMessageId, const QString &) {
        failedMessages.append(clientMessageId);
    });

    QTcpSocket *socket = connectController(&controller, &server);
    controller.subscribeTopic(QStringLiteral("room/a"));
    acknowledgeSubscription(socket, QStringLiteral("room/a"));
    controller.subscribeTopic(QStringLiteral("room/b"));
    acknowledgeSubscription(socket, QStringLiteral("room/b"));
    require(waitUntil([&]() { return confirmedChannels.contains(QStringLiteral("room/a")) && confirmedChannels.contains(QStringLiteral("room/b")); }),
            "expected subscribed channels");

    require(controller.publishMessage(QStringLiteral("room/a"), QStringLiteral("pending before disconnect")),
            "expected publish before disconnect");
    socket->disconnectFromHost();

    require(waitUntil([&]() { return !controller.connected() && removedChannels.size() == 2 && failedMessages.size() == 1; }),
            "expected disconnect to clear channels and fail pending publish");
    require(removedChannels.contains(QStringLiteral("room/a")), "expected room/a removed on disconnect");
    require(removedChannels.contains(QStringLiteral("room/b")), "expected room/b removed on disconnect");

    server.close();
}

static void testPublishRejectFailsMatchingPendingMessage()
{
    QTcpServer server;
    require(server.listen(QHostAddress::LocalHost, 0), "expected server listen");

    ChatController controller;
    QVector<int> queuedMessages;
    QVector<int> failedMessages;
    QVector<int> confirmedMessages;

    QObject::connect(&controller, &ChatController::outgoingMessageQueued,
                     [&](const QString &, const QString &, const QString &, const QString &, int clientMessageId) {
        queuedMessages.append(clientMessageId);
    });
    QObject::connect(&controller, &ChatController::outgoingMessageFailed, [&](int clientMessageId, const QString &) {
        failedMessages.append(clientMessageId);
    });
    QObject::connect(&controller, &ChatController::outgoingMessageConfirmed, [&](int clientMessageId) {
        confirmedMessages.append(clientMessageId);
    });

    QTcpSocket *socket = connectController(&controller, &server);
    controller.subscribeTopic(QStringLiteral("room/a"));
    acknowledgeSubscription(socket, QStringLiteral("room/a"));
    require(waitUntil([&]() { return controller.publishMessage(QStringLiteral("room/a"), QStringLiteral("reject me")); }),
            "expected publish to queue");
    require(queuedMessages.size() == 1, "expected queued message id");

    QByteArray rejectPayload;
    rejectPayload.append(static_cast<char>(2));
    rejectPayload.append("denied");
    sendFrame(socket, ProtocolAdapter::PublishReject, QStringLiteral("room/a"), rejectPayload);

    require(waitUntil([&]() { return failedMessages.contains(queuedMessages.first()); }),
            "expected publish reject to fail matching message");

    sendFrame(socket, ProtocolAdapter::PublishAck, QStringLiteral("room/a"));
    waitUntil([&]() { return false; }, 120);
    require(confirmedMessages.isEmpty(), "expected stale ack after reject not to confirm failed message");

    socket->close();
    server.close();
}

static void testPublishAckMatchesTopicNotQueueHead()
{
    QTcpServer server;
    require(server.listen(QHostAddress::LocalHost, 0), "expected server listen");

    ChatController controller;
    QMap<QString, int> queuedByTopic;
    QVector<int> confirmedMessages;

    QObject::connect(&controller, &ChatController::outgoingMessageQueued,
                     [&](const QString &topic, const QString &, const QString &, const QString &, int clientMessageId) {
        queuedByTopic.insert(topic, clientMessageId);
    });
    QObject::connect(&controller, &ChatController::outgoingMessageConfirmed, [&](int clientMessageId) {
        confirmedMessages.append(clientMessageId);
    });

    QTcpSocket *socket = connectController(&controller, &server);
    controller.subscribeTopic(QStringLiteral("room/a"));
    acknowledgeSubscription(socket, QStringLiteral("room/a"));
    controller.subscribeTopic(QStringLiteral("room/b"));
    acknowledgeSubscription(socket, QStringLiteral("room/b"));
    require(waitUntil([&]() { return queuedByTopic.isEmpty() && controller.publishMessage(QStringLiteral("room/a"), QStringLiteral("first")); }),
            "expected first publish");
    require(controller.publishMessage(QStringLiteral("room/b"), QStringLiteral("second")), "expected second publish");
    require(queuedByTopic.contains(QStringLiteral("room/a")) && queuedByTopic.contains(QStringLiteral("room/b")),
            "expected queued ids for both topics");

    const int roomAId = queuedByTopic.value(QStringLiteral("room/a"));
    const int roomBId = queuedByTopic.value(QStringLiteral("room/b"));

    sendFrame(socket, ProtocolAdapter::PublishAck, QStringLiteral("room/b"));
    require(waitUntil([&]() { return confirmedMessages.contains(roomBId); }),
            "expected room/b ack to confirm room/b message");
    require(!confirmedMessages.contains(roomAId), "expected room/a message to remain pending after room/b ack");

    sendFrame(socket, ProtocolAdapter::PublishAck, QStringLiteral("room/a"));
    require(waitUntil([&]() { return confirmedMessages.contains(roomAId); }),
            "expected room/a ack to confirm room/a message");

    socket->close();
    server.close();
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    testDisconnectClearsChannelsAndPending();
    testPublishRejectFailsMatchingPendingMessage();
    testPublishAckMatchesTopicNotQueueHead();

    qDebug() << "All controller tests passed!";
    return 0;
}
