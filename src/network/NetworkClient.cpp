#include "NetworkClient.h"

#include <QElapsedTimer>
#include <QTimer>

NetworkClient::NetworkClient(QObject *parent)
    : QObject(parent)
{
    connect(&m_socket, &QTcpSocket::connected, this, &NetworkClient::connected);
    connect(&m_socket, &QTcpSocket::disconnected, this, &NetworkClient::disconnected);
    connect(&m_socket, &QTcpSocket::readyRead, this, &NetworkClient::onReadyRead);
    connect(&m_socket, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError) {
        emit networkError(m_socket.errorString());
    });
}

bool NetworkClient::isConnected() const
{
    return m_socket.state() == QAbstractSocket::ConnectedState;
}

void NetworkClient::connectToHost(const QString &host, quint16 port)
{
    m_buffer.clear();
    m_drainScheduled = false;
    if (m_socket.state() != QAbstractSocket::UnconnectedState) {
        m_socket.abort();
    }
    m_socket.connectToHost(host, port);
}

void NetworkClient::disconnectFromHost()
{
    m_socket.disconnectFromHost();
}

bool NetworkClient::sendFrame(ProtocolAdapter::MessageType type, const QString &topic, const QByteArray &payload)
{
    if (!isConnected()) {
        emit networkError(QStringLiteral("not connected to server"));
        return false;
    }
    const QByteArray packet = ProtocolAdapter::pack(type, topic, payload);
    return m_socket.write(packet) == packet.size();
}

bool NetworkClient::sendFrame(const ProtocolAdapter::Frame &frame)
{
    if (!isConnected()) {
        emit networkError(QStringLiteral("not connected to server"));
        return false;
    }
    const QByteArray packet = ProtocolAdapter::packFrame(frame);
    return m_socket.write(packet) == packet.size();
}

void NetworkClient::onReadyRead()
{
    m_buffer.append(m_socket.readAll());
    if (!m_drainScheduled) {
        m_drainScheduled = true;
        QTimer::singleShot(0, this, &NetworkClient::processBufferedFrames);
    }
}

void NetworkClient::processBufferedFrames()
{
    m_drainScheduled = false;
    QElapsedTimer drainTimer;
    drainTimer.start();
    int processed = 0;

    while (processed < MaxFramesPerDrain && drainTimer.elapsed() < MaxDrainMillis) {
        ProtocolAdapter::Frame frame;
        QString error;
        const ProtocolAdapter::ParseResult result = ProtocolAdapter::tryParse(&m_buffer, &frame, &error);
        if (result == ProtocolAdapter::ParseResult::Incomplete) {
            return;
        }
        if (result == ProtocolAdapter::ParseResult::Invalid) {
            emit parseError(error);
            if (m_buffer.isEmpty()) {
                return;
            }
            continue;
        }
        emit frameReceived(frame);
        ++processed;
    }

    if (!m_buffer.isEmpty() && !m_drainScheduled) {
        m_drainScheduled = true;
        QTimer::singleShot(0, this, &NetworkClient::processBufferedFrames);
    }
}
