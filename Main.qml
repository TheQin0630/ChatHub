import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Controls as Controls
import Qt.labs.settings 1.0
import "qml/panels"

ApplicationWindow {
    id: appWindow
    width: 1360
    height: 860
    minimumWidth: 1120
    minimumHeight: 700
    visible: true
    title: "ChatHub"
    color: appTheme.window

    property string currentTopic: ""
    property string noticeText: ""
    property int serverLogOffset: 0
    property int serverLogTotal: 0
    property bool serverLogHasMore: false
    property int serverTopicOffset: 0
    property int serverTopicTotal: 0
    property bool serverTopicHasMore: false
    property bool serverTopicLoading: false
    property int pageSize: 50
    property bool serverLogLoading: false
    property int messageRevision: 0
    property int selectedRuleFd: 0
    property string selectedRuleTopic: ""
    property string relationStatusText: "No relation query yet"
    property int relationMask: 0
    property bool darkMode: false
    property bool chineseMode: false
    property real themeProgress: darkMode ? 1.0 : 0.0

    Settings {
        id: appSettings
        property string serverIp: "127.0.0.1"
        property string serverPort: "1883"
        property string nickname: "guest"
        property bool darkMode: false
        property bool chineseMode: false
    }

    property var appController: chatController

    Component.onCompleted: {
        darkMode = appSettings.darkMode
        chineseMode = appSettings.chineseMode
        relationStatusText = chineseMode ? "尚未查询关系" : "No relation query yet"
    }

    onDarkModeChanged: appSettings.darkMode = darkMode
    onChineseModeChanged: appSettings.chineseMode = chineseMode

    Behavior on themeProgress {
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    Behavior on color {
        ColorAnimation { duration: 260; easing.type: Easing.OutCubic }
    }

    function hexToRgba(hex) {
        const raw = String(hex).replace("#", "")
        const value = parseInt(raw, 16)
        return {
            r: ((value >> 16) & 255) / 255,
            g: ((value >> 8) & 255) / 255,
            b: (value & 255) / 255,
            a: 1
        }
    }

    function mixThemeColor(light, dark) {
        const l = hexToRgba(light)
        const d = hexToRgba(dark)
        const t = themeProgress
        return Qt.rgba(l.r + (d.r - l.r) * t,
                       l.g + (d.g - l.g) * t,
                       l.b + (d.b - l.b) * t,
                       l.a + (d.a - l.a) * t)
    }

    QtObject {
        id: appTheme
        readonly property color window: appWindow.mixThemeColor("#f1f5f9", "#101113")
        readonly property color surface: appWindow.mixThemeColor("#ffffff", "#1c1d20")
        readonly property color surfaceAlt: appWindow.mixThemeColor("#f6f8fb", "#25272c")
        readonly property color elevated: appWindow.mixThemeColor("#f8fafc", "#2b2e34")
        readonly property color raised: appWindow.mixThemeColor("#ffffff", "#f7f9fc")
        readonly property color line: appWindow.mixThemeColor("#dce3ec", "#343942")
        readonly property color text: appWindow.mixThemeColor("#17202a", "#ffffff")
        readonly property color fieldText: "#17202a"
        readonly property color subtext: appWindow.mixThemeColor("#4b5563", "#dfe6ee")
        readonly property color muted: appWindow.mixThemeColor("#7a8696", "#9fabb9")
        readonly property color accent: "#0a84ff"
        readonly property color accentHover: appWindow.mixThemeColor("#006edb", "#2997ff")
        readonly property color accentSoft: appWindow.mixThemeColor("#dbeafe", "#123b67")
        readonly property color success: appWindow.mixThemeColor("#168a4a", "#30d158")
        readonly property color successHover: appWindow.mixThemeColor("#0f6b3b", "#0b7f59")
        readonly property color warning: appWindow.mixThemeColor("#b76b00", "#ff9f0a")
        readonly property color danger: appWindow.mixThemeColor("#d92d20", "#ff453a")
        readonly property color dangerHover: appWindow.mixThemeColor("#b42318", "#ff6961")
        readonly property color fieldBg: appWindow.mixThemeColor("#ffffff", "#f7f9fc")
        readonly property color fieldBorder: appWindow.mixThemeColor("#bcc8d6", "#c8d1dc")
        readonly property color fieldDisabledBg: appWindow.mixThemeColor("#e5eaf1", "#d9dee6")
        readonly property color comboBg: appWindow.mixThemeColor("#ffffff", "#173e67")
        readonly property color comboHoverBg: appWindow.mixThemeColor("#f4f8ff", "#1f4f80")
        readonly property color comboPopupBg: appWindow.mixThemeColor("#ffffff", "#242a31")
        readonly property color comboText: appWindow.mixThemeColor("#17202a", "#f7fbff")
        readonly property color placeholder: appWindow.mixThemeColor("#6b7280", "#8b95a3")
        readonly property color buttonGlassBg: appWindow.mixThemeColor("#f8fafc", "#242a31")
        readonly property color buttonGlassHover: appWindow.mixThemeColor("#e9f2ff", "#303842")
        readonly property color buttonDisabledBg: appWindow.mixThemeColor("#e5eaf1", "#2a3038")
        readonly property color buttonDisabledText: appWindow.mixThemeColor("#7a8696", "#9aa4b2")
        readonly property color glassBorder: appWindow.mixThemeColor("#cbd5e1", "#536070")
        readonly property color checkboxBg: appWindow.mixThemeColor("#ffffff", "#20262d")
        readonly property color tabHover: appWindow.mixThemeColor("#eef4fb", "#303842")
        readonly property color tabBorder: appWindow.mixThemeColor("#cbd5e1", "#3a424d")
        readonly property color comboIndicator: appWindow.mixThemeColor("#5b6573", "#4b5563")
        readonly property color popupHighlight: appWindow.mixThemeColor("#dbeafe", "#123b67")
        readonly property color ownMeta: appWindow.mixThemeColor("#dcecff", "#d9ebff")
        readonly property color toastBg: appWindow.mixThemeColor("#17202a", "#f7f9fc")
        readonly property color toastBorder: appWindow.mixThemeColor("#2d3a49", "#cbd5e1")
        readonly property color toastText: appWindow.mixThemeColor("#ffffff", "#17202a")
        readonly property color accentText: "#ffffff"
        readonly property color switchThumbBorder: appWindow.mixThemeColor("#d6dde6", "#d9ebff")
    }

    ListModel { id: channelListModel }
    ListModel { id: messageListModel }
    ListModel { id: localLogListModel }
    ListModel { id: serverLogListModel }
    ListModel { id: serverTopicListModel }
    ListModel { id: connectionListModel }
    ListModel { id: subscriberListModel }

    function clippedText(value, maxLength) {
        const text = String(value).replace(/\s+/g, " ")
        if (text.length <= maxLength) return text
        return text.slice(0, maxLength) + " ..."
    }

    function topicIndex(topic) {
        for (let i = 0; i < channelListModel.count; ++i) {
            if (channelListModel.get(i).topic === topic) return i
        }
        return -1
    }

    function ensureChannel(topic) {
        const normalized = topic.trim()
        if (normalized.length === 0) return -1
        const existing = topicIndex(normalized)
        if (existing >= 0) return existing
        channelListModel.append({ topic: normalized, unread: 0, pending: false })
        if (currentTopic === "") currentTopic = normalized
        return channelListModel.count - 1
    }

    function countMessages(topic) {
        let count = 0
        for (let i = 0; i < messageListModel.count; ++i) {
            if (messageListModel.get(i).topic === topic) ++count
        }
        return count
    }

    function addLocalLog(time, level, message) {
        localLogListModel.append({ time: time, level: level, message: clippedText(message, 160) })
        while (localLogListModel.count > 80) localLogListModel.remove(0)
        workspacePanel.refreshLogsToEnd()
    }

    function showNotice(message) {
        noticeText = message
        noticeTimer.restart()
    }

    function addMessage(topic, user, message, own, forwarded, sourceTopic, time, state, clientMessageId) {
        ensureChannel(topic)
        messageListModel.append({
            topic: topic,
            user: clippedText(user, 80),
            message: clippedText(message, 1200),
            own: own,
            forwarded: forwarded,
            sourceTopic: clippedText(sourceTopic, 100),
            time: time,
            state: state,
            clientMessageId: clientMessageId
        })
        messageRevision++
        if (topic !== currentTopic) {
            const idx = topicIndex(topic)
            if (idx >= 0) channelListModel.setProperty(idx, "unread", channelListModel.get(idx).unread + 1)
        } else {
            chatPanel.positionAtEnd()
        }
    }

    function confirmOutgoing(clientMessageId) {
        for (let i = 0; i < messageListModel.count; ++i) {
            if (messageListModel.get(i).clientMessageId === clientMessageId) {
                messageListModel.setProperty(i, "state", "sent")
                messageRevision++
                return
            }
        }
    }

    function joinTopic(topic) {
        const normalized = topic.trim()
        if (normalized.length === 0) {
            showNotice(chineseMode ? "频道不能为空" : "Channel cannot be empty")
            return
        }
        const index = ensureChannel(normalized)
        if (index >= 0) channelListModel.setProperty(index, "pending", true)
        appController.subscribeTopic(normalized)
    }

    function requestLogs(offset) {
    }

    function requestTopics(offset) {
        if (serverTopicLoading) return
        serverTopicOffset = Math.max(0, offset)
        serverTopicLoading = true
        serverTopicTimeout.restart()
        if (!appController.requestServerTopics(serverTopicOffset, pageSize, true)) {
            serverTopicLoading = false
            serverTopicTimeout.stop()
        }
    }

    onCurrentTopicChanged: {
        for (let i = 0; i < channelListModel.count; ++i) {
            if (channelListModel.get(i).topic === currentTopic) {
                channelListModel.setProperty(i, "unread", 0)
                break
            }
        }
        chatPanel.positionAtEnd()
    }

    Timer {
        id: noticeTimer
        interval: 2800
        onTriggered: noticeText = ""
    }

    Timer {
        id: serverLogTimeout
        interval: 4500
        onTriggered: {
            serverLogLoading = false
            showNotice(chineseMode ? "服务端日志请求超时" : "Server log request timed out")
        }
    }

    Timer {
        id: serverTopicTimeout
        interval: 4500
        onTriggered: {
            serverTopicLoading = false
            showNotice(chineseMode ? "服务端频道请求超时" : "Server topic request timed out")
        }
    }

    Connections {
        target: appController

        function onLogAdded(time, level, message) {
            addLocalLog(time, level, message)
        }

        function onChannelConfirmed(topic) {
            const index = ensureChannel(topic)
            if (index >= 0) channelListModel.setProperty(index, "pending", false)
            currentTopic = topic
            requestTopics(0)
        }

        function onChannelRemoved(topic) {
            const index = topicIndex(topic)
            if (index >= 0) channelListModel.remove(index)
            if (currentTopic === topic) currentTopic = channelListModel.count > 0 ? channelListModel.get(0).topic : ""
        }

        function onOutgoingMessageQueued(topic, user, message, time, clientMessageId) {
            addMessage(topic, user, message, true, false, "", time, "sending", clientMessageId)
        }

        function onOutgoingMessageConfirmed(clientMessageId) {
            confirmOutgoing(clientMessageId)
        }

        function onIncomingMessage(topic, user, message, own, forwarded, sourceTopic, time) {
            addMessage(topic, user, message, own, forwarded, sourceTopic, time, "sent", 0)
        }

        function onServerLogsReceived(rows, total, offset, hasMore) {
            serverLogListModel.clear()
            const visibleRows = Math.min(rows.length, 50)
            for (let i = 0; i < visibleRows; ++i) {
                serverLogListModel.append({ line: clippedText(rows[i], 180) })
            }
            serverLogOffset = offset
            serverLogTotal = total
            serverLogHasMore = hasMore
            serverLogLoading = false
            serverLogTimeout.stop()
        }

        function onServerTopicsReceived(rows, total, offset, hasMore) {
            serverTopicListModel.clear()
            const visibleRows = rows.length
            for (let i = 0; i < visibleRows; ++i) {
                serverTopicListModel.append({ topic: clippedText(rows[i].topic, 120), subscribers: rows[i].subscribers })
            }
            serverTopicOffset = offset
            serverTopicTotal = total
            serverTopicHasMore = hasMore
            serverTopicLoading = false
            serverTopicTimeout.stop()
        }

        function onServerSnapshotReceived(title, body) {
            showNotice(chineseMode ? "工作区展示实时频道和客户端日志" : "Workspace uses live channel and client log views")
        }

        function onConnectedChanged() {
            if (appController.connected) {
                requestTopics(0)
            }
        }

        function onServerConnectionsReceived(connections) {
            connectionListModel.clear()
            for (let i = 0; i < connections.length; ++i) {
                connectionListModel.append({
                    fd: connections[i].fd,
                    ip: connections[i].ip,
                    port: connections[i].port
                })
            }
            selectedRuleFd = connectionListModel.count > 0 ? connectionListModel.get(0).fd : 0
        }

        function onTopicSubscribersReceived(topic, subscribers) {
            subscriberListModel.clear()
            selectedRuleTopic = topic
            for (let i = 0; i < subscribers.length; ++i) {
                subscriberListModel.append({
                    fd: subscribers[i].fd,
                    ip: subscribers[i].ip,
                    port: subscribers[i].port
                })
            }
            if (subscriberListModel.count > 0) selectedRuleFd = subscriberListModel.get(0).fd
        }

        function onTopicSubscribersStateReceived(topic, status) {
            if (status === 1) showNotice((chineseMode ? "未找到频道：" : "Topic not found: ") + topic)
        }

        function onRuleSetResult(status) {
            if (status === 0) {
                appController.requestConnectionList()
                if (selectedRuleTopic !== "") appController.requestTopicSubscribers(selectedRuleTopic)
                if (selectedRuleTopic !== "" && selectedRuleFd > 0) appController.requestFdTopicRelation(selectedRuleTopic, selectedRuleFd)
            }
        }

        function onFdTopicRelationReceived(topic, fd, status, mask) {
            relationMask = mask
            if (status === 0) {
                const parts = []
                if ((mask & 1) !== 0) parts.push("subscribed")
                if ((mask & 2) !== 0) parts.push("deny sub")
                if ((mask & 4) !== 0) parts.push("deny recv")
                if ((mask & 8) !== 0) parts.push("deny publish")
                relationStatusText = "fd " + fd + " / " + topic + ": " + parts.join(", ")
            } else {
                relationStatusText = chineseMode ? ("fd " + fd + " / " + topic + ": 无显式关系") : ("fd " + fd + " / " + topic + ": no explicit relation")
            }
        }

        function onUserMessage(message) {
            showNotice(message)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar {
            theme: appTheme
            chatController: appController
            settings: appSettings
            darkMode: appWindow.darkMode
            chineseMode: appWindow.chineseMode
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            onConnectRequested: (host, port, nickname) => appController.connectToServer(host, port, nickname)
            onDisconnectRequested: appController.disconnectFromServer()
            onThemeRequested: dark => appWindow.darkMode = dark
            onLanguageRequested: chinese => appWindow.chineseMode = chinese
        }

        Controls.SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            ChannelsPanel {
                theme: appTheme
                chatController: appController
                channelModel: channelListModel
                currentTopic: appWindow.currentTopic
                chineseMode: appWindow.chineseMode
                Controls.SplitView.preferredWidth: 286
                Controls.SplitView.minimumWidth: 220
                Controls.SplitView.maximumWidth: 420
                onJoinRequested: topic => joinTopic(topic)
                onLeaveRequested: topic => appController.unsubscribeTopic(topic)
                onTopicSelected: topic => currentTopic = topic
            }

            ChatPanel {
                id: chatPanel
                theme: appTheme
                chatController: appController
                messageModel: messageListModel
                channelModel: channelListModel
                currentTopic: appWindow.currentTopic
                messageRevision: appWindow.messageRevision
                messageCount: countMessages(appWindow.currentTopic)
                chineseMode: appWindow.chineseMode
                Controls.SplitView.fillWidth: true
                Controls.SplitView.minimumWidth: 420
                onSendRequested: (text, reliable, retain) => {
                    if (appController.publishMessageAdvanced(currentTopic, text, reliable, retain)) {
                        chatPanel.clearMessage()
                    }
                }
                onChannelSelected: topic => currentTopic = topic
                onRefreshRequested: {
                    requestTopics(0)
                }
            }

            WorkspacePanel {
                id: workspacePanel
                theme: appTheme
                chatController: appController
                channelModel: channelListModel
                messageModel: messageListModel
                serverTopicModel: serverTopicListModel
                serverLogModel: serverLogListModel
                localLogModel: localLogListModel
                connectionModel: connectionListModel
                subscriberModel: subscriberListModel
                currentTopic: appWindow.currentTopic
                serverTopicOffset: appWindow.serverTopicOffset
                serverTopicTotal: appWindow.serverTopicTotal
                serverTopicHasMore: appWindow.serverTopicHasMore
                serverTopicLoading: appWindow.serverTopicLoading
                serverLogOffset: appWindow.serverLogOffset
                serverLogTotal: appWindow.serverLogTotal
                serverLogHasMore: appWindow.serverLogHasMore
                serverLogLoading: appWindow.serverLogLoading
                pageSize: appWindow.pageSize
                selectedRuleFd: appWindow.selectedRuleFd
                relationStatusText: appWindow.relationStatusText
                relationMask: appWindow.relationMask
                chineseMode: appWindow.chineseMode
                Controls.SplitView.preferredWidth: 350
                Controls.SplitView.minimumWidth: 300
                Controls.SplitView.maximumWidth: 520
                onRequestTopics: offset => requestTopics(offset)
                onRequestLogs: offset => requestLogs(offset)
                onRequestConnections: appController.requestConnectionList()
                onRequestSubscribers: topic => {
                    appWindow.selectedRuleTopic = topic
                    appController.requestTopicSubscribers(topic)
                }
                onSelectRuleFd: fd => appWindow.selectedRuleFd = fd
                onAddRule: (topic, mask) => {
                    appWindow.selectedRuleTopic = topic
                    appController.setConnectionRule(topic, appWindow.selectedRuleFd, mask, true)
                }
                onRemoveRule: (topic, mask) => {
                    appWindow.selectedRuleTopic = topic
                    appController.setConnectionRule(topic, appWindow.selectedRuleFd, mask, false)
                }
                onCheckRelation: topic => {
                    appWindow.selectedRuleTopic = topic
                    appWindow.relationStatusText = appWindow.chineseMode ? ("正在查询 fd " + appWindow.selectedRuleFd + " / " + topic) : ("Querying fd " + appWindow.selectedRuleFd + " on " + topic)
                    appWindow.relationMask = 0
                    appController.requestFdTopicRelation(topic, appWindow.selectedRuleFd)
                }
                onJoinServerTopic: topic => joinTopic(topic)
                onLeaveServerTopic: topic => appController.unsubscribeTopic(topic)
                onNoticeRequested: message => showNotice(message)
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: Math.min(520, noticeLabel.implicitWidth + 36)
        height: 48
        radius: 24
        color: appTheme.toastBg
        border.color: appTheme.toastBorder
        border.width: 1
        visible: noticeText !== ""

        Label {
            id: noticeLabel
            anchors.centerIn: parent
            text: noticeText
            color: appTheme.toastText
            font.pixelSize: 14
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}

