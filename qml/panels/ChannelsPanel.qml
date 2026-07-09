import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../components"

Rectangle {
    id: root
    required property var theme
    required property var chatController
    required property var channelModel
    required property string currentTopic
    required property bool chineseMode

    signal joinRequested(string topic)
    signal leaveRequested(string topic)
    signal topicSelected(string topic)

    color: theme.surface
    border.color: theme.line
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        SectionTitle {
            theme: root.theme
            text: root.chineseMode ? "频道" : "Channels"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Field {
                id: topicInput
                theme: root.theme
                Layout.fillWidth: true
                placeholderText: root.chineseMode ? "room/general 或自定义频道" : "room/general"
                enabled: root.chatController.connected
                onAccepted: addTopicButton.clicked()
            }

            AppButton {
                id: addTopicButton
                theme: root.theme
                Layout.preferredWidth: 44
                text: "+"
                font.pixelSize: 20
                enabled: root.chatController.connected && topicInput.text.trim().length > 0
                fill: root.theme.success
                hoverFill: root.theme.successHover
                onClicked: {
                    root.joinRequested(topicInput.text)
                    topicInput.clear()
                }
            }
        }

        ListView {
            id: channelView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.channelModel
            reuseItems: true

            delegate: Rectangle {
                width: channelView.width
                height: 58
                radius: 8
                color: model.topic === root.currentTopic ? root.theme.accentSoft : (channelHover.hovered ? root.theme.elevated : root.theme.surface)
                border.color: model.topic === root.currentTopic ? root.theme.accent : root.theme.line
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 9
                        Layout.preferredHeight: 9
                        radius: 5
                        color: model.pending ? root.theme.warning : root.theme.success
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            text: model.topic
                            color: root.theme.text
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Label {
                            text: !root.chatController.connected ? (root.chineseMode ? "离线" : "offline") : (model.pending ? (root.chineseMode ? "等待确认" : "waiting for ack") : (root.chineseMode ? "已订阅" : "subscribed"))
                            color: root.theme.subtext
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        visible: model.unread > 0
                        Layout.preferredWidth: Math.max(24, unreadText.implicitWidth + 10)
                        Layout.preferredHeight: 22
                        radius: 11
                        color: root.theme.danger
                        Text {
                            id: unreadText
                            anchors.centerIn: parent
                            text: model.unread
                            color: root.theme.accentText
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    AppButton {
                        theme: root.theme
                        visible: channelHover.hovered
                        Layout.preferredWidth: 58
                        implicitHeight: 30
                        text: root.chineseMode ? "退出" : "Leave"
                        font.pixelSize: 12
                        fill: "transparent"
                        foreground: root.theme.danger
                        enabled: root.chatController.connected && !model.pending
                        onClicked: root.leaveRequested(model.topic)
                    }
                }

                HoverHandler { id: channelHover }
                TapHandler { onTapped: root.topicSelected(model.topic) }
            }
        }
    }
}
