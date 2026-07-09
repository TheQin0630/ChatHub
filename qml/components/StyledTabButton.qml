import QtQuick
import QtQuick.Controls.Basic

TabButton {
    id: control
    required property var theme

    implicitHeight: 34
    hoverEnabled: true
    font.pixelSize: 13
    font.weight: checked ? Font.Medium : Font.Normal

    contentItem: Text {
        text: control.text
        color: control.checked ? control.theme.accentText : control.theme.subtext
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        renderType: Text.CurveRendering
    }

    background: Rectangle {
        antialiasing: true
        radius: height / 2
        color: control.checked ? control.theme.accent : (control.hovered ? control.theme.tabHover : "transparent")
        border.color: "transparent"
        border.width: 0
    }
}
