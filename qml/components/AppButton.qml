import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    required property var theme
    property color fill: theme.accent
    property color hoverFill: theme.accentHover
    property color foreground: theme.accentText
    property bool glass: fill === "transparent"

    implicitHeight: 42
    font.pixelSize: 14
    font.weight: Font.DemiBold
    hoverEnabled: true
    opacity: enabled ? 1.0 : 0.55
    scale: pressed ? 0.965 : (hovered ? 1.015 : 1.0)

    Behavior on scale {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    contentItem: Text {
        text: control.text
        color: control.enabled ? control.foreground : control.theme.buttonDisabledText
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: height / 2
        color: control.enabled
               ? (control.glass ? (control.hovered ? control.theme.buttonGlassHover : control.theme.buttonGlassBg) : (control.hovered ? control.hoverFill : control.fill))
               : control.theme.buttonDisabledBg
        border.color: control.glass ? control.theme.glassBorder : "transparent"
        border.width: control.glass ? 1 : 0

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
