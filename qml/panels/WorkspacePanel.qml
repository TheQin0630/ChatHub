import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Controls as Controls
import "../components"

Rectangle {
    id: root
    required property var theme
    required property var chatController
    required property var channelModel
    required property var messageModel
    required property var serverTopicModel
    required property var serverLogModel
    required property var localLogModel
    required property var connectionModel
    required property var subscriberModel
    required property string currentTopic
    required property int serverTopicOffset
    required property int serverTopicTotal
    required property bool serverTopicHasMore
    required property bool serverTopicLoading
    required property int serverLogOffset
    required property int serverLogTotal
    required property bool serverLogHasMore
    required property bool serverLogLoading
    required property int pageSize
    required property int selectedRuleFd
    required property string relationStatusText
    required property int relationMask
    required property bool chineseMode

    signal requestTopics(int offset)
    signal requestLogs(int offset)
    signal requestConnections()
    signal requestSubscribers(string topic)
    signal selectRuleFd(int fd)
    signal addRule(string topic, int mask)
    signal removeRule(string topic, int mask)
    signal checkRelation(string topic)
    signal joinServerTopic(string topic)
    signal leaveServerTopic(string topic)
    signal noticeRequested(string message)

    function isJoinedTopic(topic) {
        for (let i = 0; i < channelModel.count; ++i) {
            if (channelModel.get(i).topic === topic) return true
        }
        return false
    }

    function currentRuleMask() {
        let mask = 0
        if (denySubCheck.checked) mask |= 2
        if (denyRecvCheck.checked) mask |= 4
        if (denyPubCheck.checked) mask |= 8
        return mask
    }

    function selectedRuleTopic() {
        return ruleTopicInput.text.trim()
    }

    function refreshLogsToEnd() {
        logScrollTimer.restart()
    }

    color: theme.surface
    border.color: theme.line
    border.width: 1

    Timer {
        id: logScrollTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (rightTabs.currentIndex === 2) {
                localLogView.positionViewAtEnd()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        SectionTitle {
            theme: root.theme
            text: root.chineseMode ? "工作区" : "Workspace"
        }

        TabBar {
            id: rightTabs
            Layout.fillWidth: true
            spacing: 8
            background: Item {}
            StyledTabButton { theme: root.theme; text: root.chineseMode ? "概览" : "Overview" }
            StyledTabButton { theme: root.theme; text: root.chineseMode ? "服务端" : "Server" }
            StyledTabButton { theme: root.theme; text: root.chineseMode ? "日志" : "Logs" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: rightTabs.currentIndex

            ScrollView {
                id: overviewScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: overviewScroll.availableWidth
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        radius: 8
                        color: root.theme.elevated
                        border.color: root.theme.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4
                            Label {
                                text: root.chatController.connected ? (root.chineseMode ? "已连接" : "Connected") : (root.chineseMode ? "未连接" : "Disconnected")
                                color: root.chatController.connected ? root.theme.success : root.theme.subtext
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: root.chineseMode ? ("频道 " + root.channelModel.count + " | 消息 " + root.messageModel.count) : ("Channels " + root.channelModel.count + " | Messages " + root.messageModel.count)
                                color: root.theme.subtext
                                font.pixelSize: 13
                            }
                            Label {
                                Layout.fillWidth: true
                                text: root.currentTopic === "" ? (root.chineseMode ? "当前没有活跃频道" : "No active channel") : ((root.chineseMode ? "当前频道：" : "Active channel: ") + root.currentTopic)
                                color: root.theme.text
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                        }
                    }

                    SectionTitle { theme: root.theme; text: root.chineseMode ? "连接规则" : "Connection rules" }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        AppButton {
                            theme: root.theme
                            Layout.fillWidth: true
                            text: root.chineseMode ? "刷新连接" : "Refresh Connections"
                            enabled: root.chatController.connected
                            onClicked: root.requestConnections()
                        }
                        AppButton {
                            theme: root.theme
                            Layout.preferredWidth: 94
                            text: root.chineseMode ? "订阅者" : "Subs"
                            fill: "transparent"
                            foreground: root.theme.accent
                            enabled: root.chatController.connected && ruleTopicInput.text.trim().length > 0
                            onClicked: root.requestSubscribers(ruleTopicInput.text.trim())
                        }
                    }

                    Field {
                        id: ruleTopicInput
                        theme: root.theme
                        Layout.fillWidth: true
                        text: root.currentTopic
                        placeholderText: root.chineseMode ? "规则频道" : "Rule topic"
                        enabled: root.chatController.connected
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.selectedRuleFd > 0 ? ((root.chineseMode ? "目标 fd " : "Target fd ") + root.selectedRuleFd) : (root.chineseMode ? "请在下方选择 fd" : "Select an fd below")
                        color: root.selectedRuleFd > 0 ? root.theme.text : root.theme.subtext
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    ListView {
                        id: connectionList
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        model: root.connectionModel
                        clip: true
                        spacing: 6
                        reuseItems: true
                        delegate: Rectangle {
                            width: connectionList.width
                            height: 38
                            radius: 8
                            color: model.fd === root.selectedRuleFd ? root.theme.accentSoft : root.theme.elevated
                            border.color: model.fd === root.selectedRuleFd ? root.theme.accent : root.theme.line
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                Label {
                                    Layout.preferredWidth: 58
                                    text: "fd " + model.fd
                                    color: root.theme.text
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: model.ip + ":" + model.port
                                    color: root.theme.subtext
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    connectionList.currentIndex = index
                                    root.selectRuleFd(model.fd)
                                }
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 1
                        rowSpacing: 8
                        StyledCheckBox {
                            id: denySubCheck
                            theme: root.theme
                            Layout.fillWidth: true
                            text: root.chineseMode ? "禁止订阅" : "Deny sub"
                            description: root.chineseMode ? "阻止该 fd 订阅选中的频道。" : "Blocks this fd from subscribing to the selected topic."
                            enabled: root.chatController.connected
                        }
                        StyledCheckBox {
                            id: denyRecvCheck
                            theme: root.theme
                            Layout.fillWidth: true
                            text: root.chineseMode ? "禁止接收" : "Deny recv"
                            description: root.chineseMode ? "阻止服务端向该 fd 投递此频道消息。" : "Keeps server deliveries from reaching this fd on this topic."
                            enabled: root.chatController.connected
                        }
                        StyledCheckBox {
                            id: denyPubCheck
                            theme: root.theme
                            Layout.fillWidth: true
                            text: root.chineseMode ? "禁止发布" : "Deny publish"
                            description: root.chineseMode ? "拒绝该 fd 向此频道发布消息。" : "Rejects publish attempts from this fd for this topic."
                            enabled: root.chatController.connected
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8
                        AppButton {
                            theme: root.theme
                            Layout.fillWidth: true
                            text: root.chineseMode ? "添加规则" : "Add Rule"
                            enabled: root.chatController.connected
                            fill: root.theme.success
                            hoverFill: root.theme.successHover
                            onClicked: {
                                const topic = root.selectedRuleTopic()
                                const mask = root.currentRuleMask()
                                if (topic.length === 0) {
                                    root.noticeRequested(root.chineseMode ? "规则频道不能为空" : "Rule topic cannot be empty")
                                } else if (root.selectedRuleFd <= 0) {
                                    root.noticeRequested(root.chineseMode ? "请选择一个在线连接" : "Select an online connection")
                                } else if (mask === 0) {
                                    root.noticeRequested(root.chineseMode ? "请至少选择一条规则" : "Select at least one rule")
                                } else {
                                    root.addRule(topic, mask)
                                }
                            }
                        }
                        AppButton {
                            theme: root.theme
                            Layout.fillWidth: true
                            text: root.chineseMode ? "移除" : "Remove"
                            enabled: root.chatController.connected
                            fill: "transparent"
                            foreground: root.theme.danger
                            onClicked: {
                                const topic = root.selectedRuleTopic()
                                const mask = root.currentRuleMask()
                                if (topic.length === 0) {
                                    root.noticeRequested(root.chineseMode ? "规则频道不能为空" : "Rule topic cannot be empty")
                                } else if (root.selectedRuleFd <= 0) {
                                    root.noticeRequested(root.chineseMode ? "请选择一个在线连接" : "Select an online connection")
                                } else if (mask === 0) {
                                    root.noticeRequested(root.chineseMode ? "请至少选择一条规则" : "Select at least one rule")
                                } else {
                                    root.removeRule(topic, mask)
                                }
                            }
                        }
                        AppButton {
                            theme: root.theme
                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            text: root.chineseMode ? "检查关系" : "Check Relation"
                            enabled: root.chatController.connected && root.selectedRuleFd > 0 && ruleTopicInput.text.trim().length > 0
                            fill: "transparent"
                            foreground: root.theme.accent
                            onClicked: root.checkRelation(ruleTopicInput.text.trim())
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.relationStatusText
                        color: root.relationMask === 0 ? root.theme.subtext : root.theme.text
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    SectionTitle { theme: root.theme; text: root.chineseMode ? "频道订阅者" : "Topic subscribers" }

                    ListView {
                        id: subscriberList
                        Layout.fillWidth: true
                        Layout.preferredHeight: 96
                        model: root.subscriberModel
                        clip: true
                        spacing: 6
                        reuseItems: true
                        delegate: Rectangle {
                            width: subscriberList.width
                            height: 34
                            radius: 8
                            color: model.fd === root.selectedRuleFd ? root.theme.accentSoft : root.theme.elevated
                            border.color: model.fd === root.selectedRuleFd ? root.theme.accent : root.theme.line
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                Label {
                                    Layout.preferredWidth: 58
                                    text: "fd " + model.fd
                                    color: root.theme.text
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: model.ip + ":" + model.port
                                    color: root.theme.subtext
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    subscriberList.currentIndex = index
                                    root.selectRuleFd(model.fd)
                                }
                            }
                        }
                    }

                    SectionTitle { theme: root.theme; text: root.chineseMode ? "快速检查" : "Quick check" }
                    Label {
                        Layout.fillWidth: true
                        text: root.chineseMode ? "连接服务器，加入 room/general，再启动另一个客户端加入同一频道，然后在两个窗口互发消息。" : "Connect, join room/general, launch another client, join the same channel, then send messages from both windows."
                        color: root.theme.subtext
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ColumnLayout {
                spacing: 10

                Label {
                    Layout.fillWidth: true
                    text: root.serverTopicLoading ? (root.chineseMode ? "正在加载频道..." : "Loading channels...") : (root.chineseMode ? ("服务端频道 " + root.serverTopicModel.count) : ("Server channels " + root.serverTopicModel.count))
                    color: root.theme.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                ListView {
                    id: serverTopicList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.serverTopicModel
                    clip: true
                    spacing: 7
                    reuseItems: true
                    opacity: root.serverTopicLoading ? 0.58 : 1
                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    delegate: Rectangle {
                        width: serverTopicList.width
                        height: 48
                        radius: 8
                        color: serverTopicHover.hovered ? root.theme.accentSoft : root.theme.elevated
                        border.color: serverTopicHover.hovered ? root.theme.accent : root.theme.line
                        Behavior on color {
                            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on border.color {
                            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            Label {
                                Layout.fillWidth: true
                                text: model.topic
                                color: root.theme.text
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Label {
                                text: root.chineseMode ? (model.subscribers + " 订阅") : (model.subscribers + " subs")
                                color: root.theme.subtext
                                font.pixelSize: 12
                            }
                            AppButton {
                                theme: root.theme
                                visible: serverTopicHover.hovered
                                Layout.preferredWidth: 64
                                implicitHeight: 30
                                text: root.isJoinedTopic(model.topic) ? (root.chineseMode ? "退出" : "Leave") : (root.chineseMode ? "加入" : "Join")
                                font.pixelSize: 12
                                fill: root.isJoinedTopic(model.topic) ? "transparent" : root.theme.accent
                                foreground: root.isJoinedTopic(model.topic) ? root.theme.danger : root.theme.accentText
                                enabled: root.chatController.connected
                                onClicked: root.isJoinedTopic(model.topic) ? root.leaveServerTopic(model.topic) : root.joinServerTopic(model.topic)
                            }
                        }
                        HoverHandler { id: serverTopicHover }
                        TapHandler { onTapped: serverTopicList.currentIndex = index }
                    }
                }
            }

            ColumnLayout {
                spacing: 10

                Label {
                    Layout.fillWidth: true
                    text: root.chineseMode ? ("客户端连接日志 " + root.localLogModel.count) : ("Client connection log " + root.localLogModel.count)
                    color: root.theme.subtext
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                ListView {
                    id: localLogView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: root.localLogModel
                    clip: true
                    spacing: 6
                    reuseItems: true
                    delegate: Rectangle {
                        width: localLogView.width
                        height: 58
                        radius: 8
                        color: root.theme.elevated
                        border.color: root.theme.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            Label {
                                text: model.time + "  " + model.level
                                color: model.level === "ERROR" ? root.theme.danger : (model.level === "WARN" ? root.theme.warning : root.theme.subtext)
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: model.message
                                color: root.theme.text
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }
            }
        }
    }
}
