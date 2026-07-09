import QtQuick
import QtQuick.Controls.Basic

Switch {
    id: control
    required property var theme
    required property bool darkMode
    required property bool chineseMode
    signal modeRequested(bool dark)

    text: darkMode ? (chineseMode ? "深色" : "Dark") : (chineseMode ? "浅色" : "Light")
    checked: darkMode
    implicitWidth: 112
    implicitHeight: 40
    spacing: 9
    hoverEnabled: true
    onToggled: modeRequested(checked)

    Behavior on checked {
        enabled: false
    }

    indicator: Rectangle {
        antialiasing: true
        implicitWidth: 32
        implicitHeight: 32
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 16
        color: control.checked ? control.theme.accentSoft : control.theme.surfaceAlt
        border.color: control.theme.glassBorder
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Text {
            anchors.centerIn: parent
            text: control.checked ? "☾" : "☀"
            color: control.checked ? control.theme.accent : control.theme.warning
            font.pixelSize: 16
            font.weight: Font.Medium
            rotation: control.checked ? 0 : 180
            renderType: Text.CurveRendering

            Behavior on color {
                ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Behavior on rotation {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
        }
    }

    contentItem: Label {
        text: control.text
        color: control.theme.text
        font.pixelSize: 14
        font.weight: Font.Normal
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
        elide: Text.ElideRight
        renderType: Text.CurveRendering

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
