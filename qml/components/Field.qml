import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: control
    required property var theme

    color: enabled ? theme.fieldText : theme.muted
    selectedTextColor: theme.accentText
    selectionColor: theme.accent
    font.pixelSize: 13
    font.weight: Font.Normal
    leftPadding: 14
    rightPadding: 14
    topPadding: 8
    bottomPadding: 8
    implicitHeight: 38
    placeholderTextColor: theme.placeholder

    background: Rectangle {
        antialiasing: true
        radius: height / 2
        color: control.enabled ? control.theme.fieldBg : control.theme.fieldDisabledBg
        border.color: control.activeFocus ? control.theme.accent : control.theme.fieldBorder
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }
}
