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
    implicitHeight: 42
    spacing: 8
    hoverEnabled: true
    onToggled: modeRequested(checked)

    indicator: Rectangle {
        implicitWidth: 50
        implicitHeight: 28
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 14
        color: control.checked ? control.theme.accent : control.theme.fieldDisabledBg
        border.color: control.checked ? control.theme.accent : control.theme.line
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Rectangle {
            x: control.checked ? parent.width - width - 4 : 4
            y: 4
            width: 20
            height: 20
            radius: 10
            color: control.theme.accentText
            border.color: control.checked ? control.theme.switchThumbBorder : control.theme.line
            border.width: 1

            Behavior on x {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            Behavior on border.color {
                ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }
    }

    contentItem: Label {
        text: control.text
        color: control.theme.subtext
        font.pixelSize: 13
        font.weight: Font.DemiBold
        verticalAlignment: Text.AlignVCenter
        leftPadding: control.indicator.width + control.spacing
    }
}
