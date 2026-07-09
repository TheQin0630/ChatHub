#include "../src/network/NetworkClient.h"

#include <QCoreApplication>
#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTimer>
#include <QDebug>

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

    QTcpServer server;
    require(server.listen(QHostAddress::LocalHost, 0), "expected local test server to listen");

    NetworkClient client;
    constexpr int frameCount = 240;
    int received = 0;
    int heartbeatTicks = 0;

    QTimer heartbeat;
    heartbeat.setInterval(1);
    QObject::connect(&heartbeat, &QTimer::timeout, [&]() {
        ++heartbeatTicks;
    });
    heartbeat.start();

    QObject::connect(&client, &NetworkClient::frameReceived, [&](const ProtocolAdapter::Frame &frame) {
        require(frame.type == ProtocolAdapter::PublishAck, "expected publish ack frame");
        ++received;
        if (received == frameCount) {
            app.quit();
        }
    });

    QObject::connect(&server, &QTcpServer::newConnection, [&]() {
        QTcpSocket *socket = server.nextPendingConnection();
        QByteArray burst;
        for (int i = 0; i < frameCount; ++i) {
            burst.append(ProtocolAdapter::pack(ProtocolAdapter::PublishAck, QStringLiteral("room/test")));
        }
        socket->write(burst);
        socket->flush();
    });

    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&timeout, &QTimer::timeout, [&]() {
        qCritical() << "timed out waiting for network frames, received" << received;
        std::exit(1);
    });
    timeout.start(5000);

    client.connectToHost(QStringLiteral("127.0.0.1"), server.serverPort());
    app.exec();

    require(received == frameCount, "expected all burst frames to be received");
    require(heartbeatTicks > 0, "expected event loop to keep ticking during burst processing");

    qDebug() << "Network client burst test passed!";
    return 0;
}
