import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: control
    required property var theme

    color: enabled ? theme.fieldText : theme.muted
    selectedTextColor: theme.accentText
    selectionColor: theme.accent
    font.pixelSize: 14
    padding: 12
    placeholderTextColor: theme.placeholder

    background: Rectangle {
        radius: 16
        color: control.enabled ? control.theme.fieldBg : control.theme.fieldDisabledBg
        border.color: control.activeFocus ? control.theme.accent : control.theme.fieldBorder
        border.width: control.activeFocus ? 2 : 1

        Behavior on color {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
        }
    }
}
