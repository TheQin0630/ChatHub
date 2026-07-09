#pragma once

#include "../protocol/ProtocolAdapter.h"

#include <QObject>
#include <QTcpSocket>

class NetworkClient : public QObject
{
    Q_OBJECT

public:
    explicit NetworkClient(QObject *parent = nullptr);

    bool isConnected() const;
    void connectToHost(const QString &host, quint16 port);
    void disconnectFromHost();
    bool sendFrame(ProtocolAdapter::MessageType type, const QString &topic, const QByteArray &payload = {});
    bool sendFrame(const ProtocolAdapter::Frame &frame);

signals:
    void connected();
    void disconnected();
    void frameReceived(ProtocolAdapter::Frame frame);
    void networkError(QString message);
    void parseError(QString message);

private slots:
    void onReadyRead();
    void processBufferedFrames();

private:
    static constexpr int MaxFramesPerDrain = 12;
    static constexpr int MaxDrainMillis = 6;

    QTcpSocket m_socket;
    QByteArray m_buffer;
    bool m_drainScheduled = false;
};
