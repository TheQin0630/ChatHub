import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../components"

Rectangle {
    id: root
    required property var theme
    required property var chatController
    required property var messageModel
    required property var channelModel
    required property string currentTopic
    required property int messageRevision
    required property int messageCount
    required property bool chineseMode
    property bool advancedSendOpen: false

    signal sendRequested(string text, bool reliable, bool retain)
    signal channelSelected(string topic)
    signal refreshRequested()

    function positionAtEnd() {
        messageView.positionViewAtEnd()
    }

    function clearMessage() {
        messageInput.clear()
    }

    function prefillMessage(message) {
        messageInput.text = message
        messageInput.forceActiveFocus()
    }

    function syncChannelCombo() {
        for (let i = 0; i < root.channelModel.count; ++i) {
            if (root.channelModel.get(i).topic === root.currentTopic) {
                channelCombo.currentIndex = i
                return
            }
        }
        channelCombo.currentIndex = -1
    }

    onCurrentTopicChanged: syncChannelCombo()

    color: theme.window

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 68
            color: root.theme.surface
            border.color: root.theme.line
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        text: root.currentTopic === "" ? (root.chineseMode ? "未选择频道" : "No channel selected") : "#" + root.currentTopic
                        color: root.theme.text
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Label {
                        text: root.currentTopic === "" ? (root.chineseMode ? "从左侧加入一个频道。" : "Join a channel from the left panel.") : (root.chineseMode ? ("本次会话 " + root.messageCount + " 条消息") : (root.messageCount + " messages in this session"))
                        color: root.theme.subtext
                        font.pixelSize: 12
                    }
                }

                AppButton {
                    theme: root.theme
                    Layout.preferredWidth: 108
                    text: root.chineseMode ? "刷新" : "Refresh"
                    fill: root.theme.accent
                    hoverFill: root.theme.accentHover
                    foreground: root.theme.accentText
                    enabled: root.chatController.connected
                    onClicked: root.refreshRequested()
                }
            }
        }

        ListView {
            id: messageView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.messageModel
            spacing: 10
            leftMargin: 24
            rightMargin: 24
            topMargin: 18
            bottomMargin: 18
            reuseItems: true

            delegate: Item {
                width: messageView.width - 48
                height: model.topic === root.currentTopic ? bubble.height + 4 : 0
                visible: model.topic === root.currentTopic

                Rectangle {
                    id: bubble
                    width: Math.min(parent.width * 0.72, Math.max(280, Math.min(parent.width, bodyText.implicitWidth + 42)))
                    height: bubbleColumn.implicitHeight + 24
                    radius: 8
                    color: model.own ? root.theme.accent : root.theme.surface
                    border.color: model.own ? root.theme.accent : root.theme.line
                    border.width: 1
                    anchors.right: model.own ? parent.right : undefined
                    anchors.left: model.own ? undefined : parent.left

                    Column {
                        id: bubbleColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 7

                        RowLayout {
                            width: parent.width
                            spacing: 8
                            Label {
                                Layout.fillWidth: true
                                text: model.user
                                color: model.own ? root.theme.accentText : root.theme.accent
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                text: model.state === "sending" ? (root.chineseMode ? "发送中" : "Sending") : model.time
                                color: model.own ? root.theme.ownMeta : root.theme.subtext
                                font.pixelSize: 11
                            }
                        }

                        Label {
                            visible: model.forwarded
                            text: (root.chineseMode ? "转发自 " : "Forwarded from ") + model.sourceTopic
                            color: model.own ? root.theme.ownMeta : root.theme.warning
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            id: bodyText
                            width: parent.width
                            text: model.message
                            color: model.own ? root.theme.accentText : root.theme.text
                            font.pixelSize: 15
                            lineHeight: 1.18
                            wrapMode: Text.Wrap
                            maximumLineCount: 10
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Item {
                id: emptyState
                anchors.fill: parent
                visible: root.messageRevision >= 0 && (root.currentTopic === "" || root.messageCount === 0)

                Rectangle {
                    width: Math.min(parent.width * 0.54, 500)
                    height: 118
                    radius: height / 2
                    color: root.theme.accentSoft
                    border.color: "transparent"
                    opacity: 0.52
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenterOffset: -96
                    anchors.verticalCenterOffset: -54

                    Behavior on color {
                        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }
                }

                Rectangle {
                    width: Math.min(parent.width * 0.42, 380)
                    height: 92
                    radius: height / 2
                    color: root.theme.surface
                    border.color: "transparent"
                    opacity: 0.86
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 128
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 12
                }

                Rectangle {
                    width: Math.min(parent.width * 0.30, 260)
                    height: 66
                    radius: height / 2
                    color: root.theme.elevated
                    border.color: "transparent"
                    opacity: 0.76
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -148
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 76
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: root.theme.accentSoft
                    opacity: 0.62
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: -264
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 14
                }

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: root.theme.surface
                    opacity: 0.84
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: 292
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 76
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    width: Math.min(parent.width - 64, 460)

                    Label {
                        width: parent.width
                        text: root.currentTopic === "" ? (root.chineseMode ? "你还没有加入任何频道" : "You haven't joined any channels yet") : (root.chineseMode ? "这个频道还没有消息" : "This channel has no messages yet")
                        color: root.theme.text
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        width: parent.width
                        text: root.currentTopic === ""
                              ? (root.chineseMode ? "从左侧加入频道，然后开始聊天。" : "Join a channel from the left panel to start chatting.")
                              : (root.chineseMode ? "发送第一条消息来开始对话。" : "Send the first message to start the conversation.")
                        color: root.theme.subtext
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Rectangle {
            property int targetHeight: root.advancedSendOpen ? 158 : 74
            Layout.fillWidth: true
            Layout.preferredHeight: targetHeight
            color: root.theme.surface
            border.color: root.theme.line
            border.width: 1

            Behavior on targetHeight {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    StyledComboBox {
                        id: channelCombo
                        theme: root.theme
                        Layout.preferredWidth: Math.min(220, Math.max(160, parent.width * 0.22))
                        model: root.channelModel
                        enabled: root.channelModel.count > 0
                        onActivated: root.channelSelected(root.channelModel.get(currentIndex).topic)
                    }

                    Field {
                        id: messageInput
                        theme: root.theme
                        Layout.fillWidth: true
                        placeholderText: {
                            if (!root.chatController.connected) return root.chineseMode ? "请先连接服务器" : "Connect to server first"
                            if (root.currentTopic === "") return root.chineseMode ? "请先加入频道" : "Join a channel first"
                            return (root.chineseMode ? "发送到 #" : "Message #") + root.currentTopic
                        }
                        enabled: root.chatController.connected && root.currentTopic !== ""
                        onAccepted: sendButton.clicked()
                    }

                    AppButton {
                        theme: root.theme
                        Layout.preferredWidth: 92
                        text: root.advancedSendOpen ? (root.chineseMode ? "完成" : "Done") : (root.chineseMode ? "选项" : "Options")
                        fill: root.advancedSendOpen ? root.theme.accentSoft : "transparent"
                        foreground: root.advancedSendOpen ? root.theme.accent : root.theme.accent
                        onClicked: root.advancedSendOpen = !root.advancedSendOpen
                    }

                    AppButton {
                        id: sendButton
                        theme: root.theme
                        Layout.preferredWidth: 90
                        text: root.chineseMode ? "发送" : "Send"
                        enabled: root.chatController.connected && root.currentTopic !== "" && messageInput.text.trim().length > 0
                        onClicked: root.sendRequested(messageInput.text.trim(), reliableCheck.checked, retainCheck.checked)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.advancedSendOpen
                    opacity: root.advancedSendOpen ? 1 : 0
                    spacing: 8

                    Flow {
                        Layout.fillWidth: true
                        spacing: 12

                        StyledCheckBox {
                            id: reliableCheck
                            theme: root.theme
                            width: Math.min(260, Math.max(180, parent.width / 2 - 8))
                            text: root.chineseMode ? "QoS1 确认" : "QoS1 ack"
                            description: root.chineseMode ? "选中后等待服务端确认，再标记为已发送。" : "Selected: wait for server confirmation before marking sent."
                            enabled: root.chatController.connected
                        }

                        StyledCheckBox {
                            id: retainCheck
                            theme: root.theme
                            width: Math.min(260, Math.max(180, parent.width / 2 - 8))
                            text: root.chineseMode ? "保留消息" : "Retain"
                            description: root.chineseMode ? "选中后请求服务端保留为最新消息。" : "Selected: ask the server to keep this as the latest message."
                            enabled: root.chatController.connected
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: reliableCheck.checked || retainCheck.checked
                              ? (root.chineseMode ? "取消勾选即可恢复普通发布模式。" : "Uncheck an option to return that behavior to normal publish mode.")
                              : (root.chineseMode ? "默认发送：发布一次，不保留，也不额外等待确认。" : "Default send: publish once without retain and without extra confirmation.")
                        color: root.theme.subtext
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
