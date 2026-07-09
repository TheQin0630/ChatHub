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

    color: theme.panel
    border.color: theme.line
    border.width: 1
    radius: 18
    antialiasing: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            SectionTitle {
                theme: root.theme
                text: root.chineseMode ? "频道" : "Channels"
                Layout.fillWidth: true
            }

            AppButton {
                id: addTopicButton
                theme: root.theme
                Layout.preferredWidth: 34
                implicitHeight: 34
                text: "+"
                font.pixelSize: 18
                fill: "transparent"
                foreground: root.theme.accent
                enabled: root.chatController.connected && topicInput.text.trim().length > 0
                onClicked: {
                    root.joinRequested(topicInput.text)
                    topicInput.clear()
                }
            }
        }

        Field {
            id: topicInput
            theme: root.theme
            Layout.fillWidth: true
            placeholderText: root.chineseMode ? "room/general 或自定义频道" : "room/general"
            enabled: root.chatController.connected
            onAccepted: addTopicButton.clicked()
        }

        ListView {
            id: channelView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 9
            model: root.channelModel
            reuseItems: true

            delegate: Rectangle {
                width: channelView.width
                height: 64
                radius: 15
                color: model.topic === root.currentTopic ? root.theme.accentSoft : (channelHover.hovered ? root.theme.panelAlt : root.theme.elevated)
                border.color: model.topic === root.currentTopic ? root.theme.accent : root.theme.line
                border.width: 1
                antialiasing: true

                Behavior on color {
                    ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 12
                        color: model.topic === root.currentTopic ? root.theme.buttonGlassBg : root.theme.surfaceAlt
                        border.color: root.theme.line
                        border.width: 1
                        antialiasing: true

                        Text {
                            anchors.centerIn: parent
                            text: "#"
                            color: model.topic === root.currentTopic ? root.theme.accent : root.theme.text
                            font.pixelSize: 21
                            font.weight: Font.Medium
                            renderType: Text.CurveRendering
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3

                        Label {
                            Layout.fillWidth: true
                            text: model.topic
                            color: model.topic === root.currentTopic ? root.theme.accent : root.theme.text
                            font.pixelSize: 14
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                            renderType: Text.CurveRendering
                        }

                        RowLayout {
                            spacing: 6

                            Rectangle {
                                Layout.preferredWidth: 7
                                Layout.preferredHeight: 7
                                radius: 4
                                color: model.pending ? root.theme.warning : root.theme.success
                                antialiasing: true
                            }

                            Label {
                                text: !root.chatController.connected
                                      ? (root.chineseMode ? "离线" : "offline")
                                      : (model.pending ? (root.chineseMode ? "等待确认" : "waiting for ack") : (root.chineseMode ? "已订阅" : "subscribed"))
                                color: root.theme.subtext
                                font.pixelSize: 11
                                renderType: Text.CurveRendering
                            }
                        }
                    }

                    Rectangle {
                        visible: model.unread > 0
                        Layout.preferredWidth: Math.max(24, unreadText.implicitWidth + 10)
                        Layout.preferredHeight: 22
                        radius: 11
                        color: root.theme.danger
                        antialiasing: true

                        Text {
                            id: unreadText
                            anchors.centerIn: parent
                            text: model.unread
                            color: root.theme.accentText
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            renderType: Text.CurveRendering
                        }
                    }

                    AppButton {
                        theme: root.theme
                        visible: channelHover.hovered
                        Layout.preferredWidth: 72
                        implicitHeight: 28
                        text: root.chineseMode ? "退出" : "Leave"
                        font.pixelSize: 11
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.theme.line
            opacity: 0.78
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            spacing: 18

            Button {
                id: settingsButton
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                hoverEnabled: true

                contentItem: Row {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 12, settingsIcon.width + 12 + settingsText.implicitWidth)
                    height: parent.height
                    spacing: 12

                    Canvas {
                        id: settingsIcon
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = root.theme.text
                            ctx.lineWidth = 2.4
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"

                            ctx.beginPath()
                            ctx.arc(16, 16, 4.2, 0, Math.PI * 2)
                            ctx.stroke()

                            for (let i = 0; i < 8; ++i) {
                                const angle = Math.PI / 4 * i
                                const x1 = 16 + Math.cos(angle) * 9.8
                                const y1 = 16 + Math.sin(angle) * 9.8
                                const x2 = 16 + Math.cos(angle) * 13.7
                                const y2 = 16 + Math.sin(angle) * 13.7
                                ctx.beginPath()
                                ctx.moveTo(x1, y1)
                                ctx.lineTo(x2, y2)
                                ctx.stroke()
                            }

                            const outerSegments = [
                                [0.18, 0.56], [0.98, 1.36], [1.76, 2.14], [2.54, 2.92],
                                [3.32, 3.70], [4.10, 4.48], [4.90, 5.28], [5.68, 6.06]
                            ]
                            for (let j = 0; j < outerSegments.length; ++j) {
                                ctx.beginPath()
                                ctx.arc(16, 16, 11.6, outerSegments[j][0], outerSegments[j][1])
                                ctx.stroke()
                            }
                        }
                    }

                    Label {
                        id: settingsText
                        height: parent.height
                        text: "Settings"
                        color: root.theme.text
                        font.pixelSize: 16
                        font.weight: Font.Normal
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        renderType: Text.CurveRendering
                    }
                }

                background: Rectangle {
                    radius: 12
                    color: "transparent"
                    antialiasing: true
                }
            }

            Button {
                id: aboutButton
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                hoverEnabled: true
                onClicked: aboutPopup.open()

                contentItem: Row {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 12, aboutIcon.width + 12 + aboutText.implicitWidth)
                    height: parent.height
                    spacing: 12

                    Canvas {
                        id: aboutIcon
                        width: 32
                        height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        antialiasing: true

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = root.theme.text
                            ctx.fillStyle = root.theme.text
                            ctx.lineWidth = 2.4
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.arc(16, 16, 13.2, 0, Math.PI * 2)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.arc(16, 9.8, 1.4, 0, Math.PI * 2)
                            ctx.fill()
                            ctx.beginPath()
                            ctx.moveTo(16, 15)
                            ctx.lineTo(16, 23)
                            ctx.stroke()
                        }
                    }

                    Label {
                        id: aboutText
                        height: parent.height
                        text: "About"
                        color: root.theme.text
                        font.pixelSize: 16
                        font.weight: Font.Normal
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        renderType: Text.CurveRendering
                    }
                }

                background: Rectangle {
                    radius: 12
                    color: "transparent"
                    antialiasing: true
                }
            }
        }

        Popup {
            id: aboutPopup
            x: Math.max(12, (root.width - width) / 2)
            y: Math.max(12, root.height - height - 88)
            width: Math.min(root.width - 24, 316)
            modal: false
            focus: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            padding: 0

            background: Rectangle {
                radius: 16
                color: root.theme.elevated
                border.color: root.theme.glassBorder
                border.width: 1
                antialiasing: true
            }

            contentItem: Column {
                width: aboutPopup.width
                padding: 16
                spacing: 8

                Label {
                    width: parent.width - 32
                    text: "TheQin0630/ChatHub"
                    color: root.theme.text
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    renderType: Text.CurveRendering
                }

                Label {
                    width: parent.width - 32
                    text: "https://github.com/TheQin0630/ChatHub"
                    color: root.theme.accent
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    renderType: Text.CurveRendering
                }
            }
        }
    }
}
