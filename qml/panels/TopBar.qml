import QtQuick
import QtQuick.Layouts
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

    function localizedStatus(status) {
        if (!root.chineseMode) return status
        if (status === "Connected") return "已连接"
        if (status === "Disconnected") return "未连接"
        if (status === "Connecting") return "连接中"
        if (status === "Network error") return "网络错误"
        return status
    }

    color: theme.surface
    border.color: theme.line
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 12

        AppLogo {
            theme: root.theme
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
        }

        ColumnLayout {
            Layout.preferredWidth: 160
            spacing: 1
            Label {
                text: "ChatHub"
                color: root.theme.text
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            Label {
                text: root.localizedStatus(root.chatController.statusText)
                color: root.chatController.connected ? root.theme.success : (root.chatController.busy ? root.theme.warning : root.theme.subtext)
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillWidth: true }

        Field {
            id: hostInput
            theme: root.theme
            Layout.preferredWidth: 124
            text: root.settings.serverIp
            placeholderText: root.chineseMode ? "服务器 IP" : "Server IP"
            enabled: !root.chatController.connected && !root.chatController.busy
        }

        Field {
            id: portInput
            theme: root.theme
            Layout.preferredWidth: 82
            text: root.settings.serverPort
            placeholderText: root.chineseMode ? "端口" : "Port"
            inputMethodHints: Qt.ImhDigitsOnly
            enabled: !root.chatController.connected && !root.chatController.busy
        }

        Field {
            id: nickInput
            theme: root.theme
            Layout.preferredWidth: 112
            text: root.settings.nickname
            placeholderText: root.chineseMode ? "昵称" : "Nickname"
            enabled: !root.chatController.connected && !root.chatController.busy
        }

        AppButton {
            theme: root.theme
            Layout.preferredWidth: 108
            text: root.chatController.connected ? (root.chineseMode ? "断开" : "Disconnect") : (root.chineseMode ? "连接" : "Connect")
            fill: root.chatController.connected ? root.theme.danger : root.theme.accent
            hoverFill: root.chatController.connected ? root.theme.dangerHover : root.theme.accentHover
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

        Rectangle {
            Layout.preferredWidth: 132
            Layout.preferredHeight: 42
            radius: 21
            color: root.theme.elevated
            border.color: root.theme.line
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            Behavior on border.color {
                ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: root.chatController.connected ? root.theme.accent : root.theme.buttonDisabledBg

                    Behavior on color {
                        ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.displayNickname.slice(0, 1).toUpperCase()
                        color: root.chatController.connected ? root.theme.accentText : root.theme.muted
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: root.chineseMode ? "当前用户" : "Current user"
                        color: root.theme.muted
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.displayNickname
                        color: root.theme.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }
            }
        }

        ThemeSwitch {
            theme: root.theme
            darkMode: root.darkMode
            chineseMode: root.chineseMode
            Layout.preferredWidth: 90
            onModeRequested: dark => root.themeRequested(dark)
        }

        AppButton {
            theme: root.theme
            Layout.preferredWidth: 74
            text: root.chineseMode ? "English" : "中文"
            fill: "transparent"
            foreground: root.theme.accent
            onClicked: root.languageRequested(!root.chineseMode)
        }
    }
}
