import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control
    required property var theme
    property color fill: theme.accent
    property color hoverFill: theme.accentHover
    property color foreground: theme.accentText
    property bool glass: fill === "transparent"
    property bool outlined: false

    implicitHeight: 36
    leftPadding: 16
    rightPadding: 16
    font.pixelSize: 13
    font.weight: Font.Normal
    hoverEnabled: true
    opacity: enabled ? 1.0 : 0.55

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
        renderType: Text.CurveRendering
    }

    background: Rectangle {
        antialiasing: true
        radius: height / 2
        color: control.enabled
               ? (control.glass ? (control.hovered ? control.theme.buttonGlassHover : control.theme.buttonGlassBg) : (control.hovered ? control.hoverFill : control.fill))
               : control.theme.buttonDisabledBg
        border.color: (control.glass || control.outlined) ? control.theme.glassBorder : "transparent"
        border.width: (control.glass || control.outlined) ? 1 : 0

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }
}
