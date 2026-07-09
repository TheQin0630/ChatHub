import QtQuick
import QtQuick.Controls.Basic

TabButton {
    id: control
    required property var theme

    implicitHeight: 46
    hoverEnabled: true
    font.pixelSize: 14
    font.weight: checked ? Font.DemiBold : Font.Normal

    contentItem: Text {
        text: control.text
        color: control.checked ? control.theme.accentText : control.theme.subtext
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: 18
        color: control.checked ? control.theme.accent : (control.hovered ? control.theme.tabHover : "transparent")
        border.color: control.checked ? "transparent" : control.theme.tabBorder
        border.width: control.checked ? 0 : 1
    }
}
