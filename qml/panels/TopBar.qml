import QtQuick
import QtQuick.Controls.Basic
import "../components"

Rectangle {
    id: root
    required property var theme
    required property var chatController
    required property var settings
    required property bool darkMode
    required property bool chineseMode

    signal connectRequested(string host, int port, string nickname)
    signal disconnectRequested()
    signal themeRequested(bool dark)
    signal languageRequested(bool chinese)

    property string displayNickname: nickInput.text.trim().length > 0 ? nickInput.text.trim() : "guest"
    property string avatarLetter: displayNickname.length > 0 ? displayNickname.slice(0, 1).toUpperCase() : "G"

    function localizedStatus(status) {
        if (!root.chineseMode) return status
        if (status === "Connected") return "已连接"
        if (status === "Disconnected") return "未连接"
        if (status === "Connecting") return "连接中"
        if (status === "Network error") return "网络错误"
        return status
    }

    color: theme.shell
    border.color: theme.line
    border.width: 1
    radius: 18
    antialiasing: true

    Item {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 18

        Row {
            id: brandArea
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            AppLogo {
                theme: root.theme
                width: 54
                height: 54
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: 108
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Row {
                    height: 30
                    spacing: 10

                    Label {
                        text: "ChatHub"
                        color: root.theme.text
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        renderType: Text.CurveRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    height: 24
                    spacing: 7

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.chatController.connected ? root.theme.success : (root.chatController.busy ? root.theme.warning : root.theme.muted)
                        antialiasing: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Label {
                        text: root.localizedStatus(root.chatController.statusText)
                        color: root.chatController.connected ? root.theme.success : (root.chatController.busy ? root.theme.warning : root.theme.subtext)
                        font.pixelSize: 12
                        renderType: Text.CurveRendering
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Item {
            id: controlsArea
            property bool compact: width < 1040
            property int controlSpacing: compact ? 6 : 8
            property int languageControlWidth: root.chineseMode ? (compact ? 102 : 108) : (compact ? 90 : 96)
            property int themeControlWidth: compact ? 104 : 108
            property int connectControlWidth: compact ? 98 : 104
            property int userControlWidth: compact ? 154 : 164
            property int portFieldWidth: compact ? 122 : 132
            property int nickFieldWidth: compact ? 150 : 164
            property int fixedControlsWidth: portFieldWidth + nickFieldWidth + userControlWidth + languageControlWidth + themeControlWidth + connectControlWidth + 2 + controlSpacing * 7
            property int hostFieldWidth: Math.max(compact ? 184 : 206, Math.min(compact ? 204 : 230, width - fixedControlsWidth))
            anchors.right: parent.right
            anchors.left: brandArea.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            height: 44

            Row {
                id: controlsRow
                anchors.centerIn: parent
                height: 44
                spacing: controlsArea.controlSpacing

                Item {
                    width: controlsArea.hostFieldWidth
                    height: 44

                    Field {
                        id: hostInput
                        theme: root.theme
                        anchors.fill: parent
                        leftPadding: 52
                        rightPadding: 18
                        font.pixelSize: 14
                        text: root.settings.serverIp
                        placeholderText: root.chineseMode ? "服务器 IP" : "Server IP"
                        enabled: !root.chatController.connected && !root.chatController.busy
                    }

                    Canvas {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        antialiasing: true
                        opacity: hostInput.enabled ? 1 : 0.58
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = root.theme.subtext
                            ctx.lineWidth = 2.1
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.strokeRect(4, 4, 16, 12)
                            ctx.beginPath()
                            ctx.moveTo(12, 16)
                            ctx.lineTo(12, 20)
                            ctx.moveTo(8, 20)
                            ctx.lineTo(16, 20)
                            ctx.stroke()
                        }
                    }
                }

                Item {
                    width: controlsArea.portFieldWidth
                    height: 44

                    Field {
                        id: portInput
                        theme: root.theme
                        anchors.fill: parent
                        leftPadding: 52
                        rightPadding: 16
                        font.pixelSize: 14
                        text: root.settings.serverPort
                        placeholderText: root.chineseMode ? "端口" : "Port"
                        inputMethodHints: Qt.ImhDigitsOnly
                        enabled: !root.chatController.connected && !root.chatController.busy
                    }

                    Canvas {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        antialiasing: true
                        opacity: portInput.enabled ? 1 : 0.58
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = root.theme.subtext
                            ctx.lineWidth = 2.1
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.moveTo(12, 3)
                            ctx.lineTo(20, 7)
                            ctx.lineTo(20, 17)
                            ctx.lineTo(12, 21)
                            ctx.lineTo(4, 17)
                            ctx.lineTo(4, 7)
                            ctx.closePath()
                            ctx.moveTo(12, 3)
                            ctx.lineTo(12, 12)
                            ctx.moveTo(20, 7)
                            ctx.lineTo(12, 12)
                            ctx.lineTo(4, 7)
                            ctx.stroke()
                        }
                    }
                }

                Item {
                    width: controlsArea.nickFieldWidth
                    height: 44

                    Field {
                        id: nickInput
                        theme: root.theme
                        anchors.fill: parent
                        leftPadding: 52
                        rightPadding: 18
                        font.pixelSize: 14
                        text: root.settings.nickname
                        placeholderText: root.chineseMode ? "昵称" : "Nickname"
                        enabled: !root.chatController.connected && !root.chatController.busy
                    }

                    Canvas {
                        anchors.left: parent.left
                        anchors.leftMargin: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        antialiasing: true
                        opacity: nickInput.enabled ? 1 : 0.58
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = root.theme.subtext
                            ctx.lineWidth = 2.1
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                            ctx.arc(12, 7, 4, 0, Math.PI * 2)
                            ctx.moveTo(5, 21)
                            ctx.quadraticCurveTo(12, 14, 19, 21)
                            ctx.stroke()
                        }
                    }
                }

                Rectangle {
                    width: controlsArea.userControlWidth
                    height: 44
                    radius: 22
                    color: root.theme.buttonGlassBg
                    border.color: root.theme.glassBorder
                    border.width: 1
                    antialiasing: true

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 16
                        spacing: 10

                        Rectangle {
                            width: 34
                            height: 34
                            radius: 17
                            color: root.theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                            antialiasing: true

                            Label {
                                anchors.centerIn: parent
                                text: root.avatarLetter
                                color: root.theme.accentText
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                renderType: Text.CurveRendering
                            }
                        }

                        Column {
                            width: parent.width - 56
                            spacing: 1
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                width: parent.width
                                text: root.chineseMode ? "当前用户" : "Current user"
                                color: root.theme.subtext
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                renderType: Text.CurveRendering
                            }

                            Label {
                                width: parent.width
                                text: root.displayNickname
                                color: root.theme.text
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                renderType: Text.CurveRendering
                            }
                        }
                    }
                }

                Rectangle {
                    width: controlsArea.languageControlWidth
                    height: 40
                    radius: 20
                    color: languageHover.hovered ? root.theme.buttonGlassHover : root.theme.buttonGlassBg
                    border.color: root.theme.glassBorder
                    border.width: 1
                    antialiasing: true
                    anchors.verticalCenter: parent.verticalCenter

                    Behavior on width {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: root.chineseMode ? "English" : "中文"
                        color: root.theme.accent
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        renderType: Text.CurveRendering
                    }

                    HoverHandler { id: languageHover }
                    TapHandler { onTapped: root.languageRequested(!root.chineseMode) }
                }

                ThemeSwitch {
                    theme: root.theme
                    darkMode: root.darkMode
                    chineseMode: root.chineseMode
                    width: controlsArea.themeControlWidth
                    height: 40
                    onModeRequested: dark => root.themeRequested(dark)
                }

                Item { width: 2; height: 1 }

                AppButton {
                    theme: root.theme
                    width: controlsArea.connectControlWidth
                    height: 36
                    text: root.chatController.connected ? (root.chineseMode ? "断开" : "Disconnect") : (root.chineseMode ? "连接" : "Connect")
                    fill: root.chatController.connected ? root.theme.danger : root.theme.accent
                    hoverFill: root.chatController.connected ? root.theme.dangerHover : root.theme.accentHover
                    foreground: root.theme.accentText
                    font.weight: Font.Medium
                    onClicked: {
                        if (root.chatController.connected) {
                            root.disconnectRequested()
                            return
                        }
                        root.settings.serverIp = hostInput.text
                        root.settings.serverPort = portInput.text
                        root.settings.nickname = nickInput.text
                        root.connectRequested(hostInput.text, parseInt(portInput.text), nickInput.text)
                    }
                }
            }
        }
    }
}
