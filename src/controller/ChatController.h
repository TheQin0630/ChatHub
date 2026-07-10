#pragma once

#include "../network/NetworkClient.h"

#include <QDateTime>
#include <QObject>
#include <QQueue>
#include <QSet>
#include <QVariantList>

class ChatController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)

public:
    explicit ChatController(QObject *parent = nullptr);
    ~ChatController() override;

    bool connected() const;
    bool busy() const;
    QString statusText() const;

    Q_INVOKABLE void connectToServer(const QString &host, int port, const QString &nickname);
    Q_INVOKABLE void disconnectFromServer();
    Q_INVOKABLE void subscribeTopic(const QString &topic);
    Q_INVOKABLE void unsubscribeTopic(const QString &topic);
    Q_INVOKABLE bool publishMessage(const QString &topic, const QString &message);
    Q_INVOKABLE bool publishMessageAdvanced(const QString &topic, const QString &message, bool reliable, bool retain);
    Q_INVOKABLE bool requestServerLogs(int offset, int limit, bool newestFirst);
    Q_INVOKABLE bool requestServerTopics(int offset, int limit, bool includeEmpty);
    Q_INVOKABLE void requestServerSnapshot();
    Q_INVOKABLE void requestConnectionList();
    Q_INVOKABLE void requestTopicSubscribers(const QString &topic);
    Q_INVOKABLE void requestFdTopicRelation(const QString &topic, int fd);
    Q_INVOKABLE void createTopic(const QString &topic);
    Q_INVOKABLE void deleteTopic(const QString &topic);
    Q_INVOKABLE void setRule(const QString &topic, int ruleMask, bool add);
    Q_INVOKABLE void setConnectionRule(const QString &topic, int fd, int ruleMask, bool add);
    Q_INVOKABLE void addForwardRule(const QString &sourceTopic, const QString &targetTopic);
    Q_INVOKABLE void deleteForwardRule(const QString &sourceTopic, const QString &targetTopic);

signals:
    void connectedChanged();
    void busyChanged();
    void statusTextChanged();
    void logAdded(QString time, QString level, QString message);
    void channelConfirmed(QString topic);
    void channelRemoved(QString topic);
    void publishAck(QString topic);
    void outgoingMessageQueued(QString topic, QString user, QString message, QString time, int clientMessageId);
    void outgoingMessageConfirmed(int clientMessageId);
    void outgoingMessageFailed(int clientMessageId, QString reason);
    void incomingMessage(QString topic, QString user, QString message, bool own, bool forwarded, QString sourceTopic, QString time);
    void serverLogsReceived(QStringList rows, int total, int offset, bool hasMore);
    void serverTopicsReceived(QVariantList rows, int total, int offset, bool hasMore);
    void serverSnapshotReceived(QString title, QString body);
    void serverConnectionsReceived(QVariantList connections);
    void topicSubscribersReceived(QString topic, QVariantList subscribers);
    void topicSubscribersStateReceived(QString topic, int status);
    void fdTopicRelationReceived(QString topic, int fd, int status, int relationMask);
    void topicCreated(QString topic, int status);
    void topicDeleted(QString topic, int status);
    void ruleSetResult(int status);
    void userMessage(QString message);

private:
    struct PendingPublish {
        QString topic;
        QString message;
        QDateTime timestamp;
        int packetId = 0;
        int clientMessageId = 0;
        bool extended = false;
    };

    void setBusy(bool busy);
    void setStatusText(const QString &statusText);
    void appendLog(const QString &level, const QString &message);
    void handleFrame(const ProtocolAdapter::Frame &frame);
    void resetSessionState(const QString &reason);
    void failAllPendingPublishes(const QString &reason);
    bool confirmPendingPublish(const ProtocolAdapter::Frame &frame);
    bool failPendingPublish(const ProtocolAdapter::Frame &frame, const QString &reason);
    int nextPacketId();
    int nextRequestId();

    NetworkClient m_network;
    bool m_busy = false;
    QString m_statusText = QStringLiteral("Disconnected");
    QString m_nickname = QStringLiteral("guest");
    QSet<QString> m_channels;
    QQueue<PendingPublish> m_pendingPublishes;
    QSet<QString> m_pendingSubscribeAfterCreate;
    int m_nextPacketId = 1;
    int m_nextRequestId = 1;
    int m_nextClientMessageId = 1;
};
