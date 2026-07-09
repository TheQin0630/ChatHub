import QtQuick
import QtQuick.Controls.Basic

CheckBox {
    id: control
    required property var theme
    property string description: ""

    font.pixelSize: 13
    font.weight: Font.Normal
    spacing: 8
    hoverEnabled: true
    implicitHeight: Math.max(32, checkContent.implicitHeight + 2)

    contentItem: Column {
        id: checkContent
        leftPadding: control.indicator.width + control.spacing
        spacing: 2

        Text {
            width: Math.max(0, control.width - control.indicator.width - control.spacing)
            text: control.text
            font: control.font
            color: control.enabled ? control.theme.text : control.theme.subtext
            elide: Text.ElideRight
            renderType: Text.CurveRendering
        }

        Text {
            width: Math.max(0, control.width - control.indicator.width - control.spacing)
            text: control.checked ? control.description : ""
            visible: text.length > 0
            opacity: control.checked ? 1 : 0
            color: control.theme.subtext
            font.pixelSize: 11
            wrapMode: Text.WordWrap
            renderType: Text.CurveRendering

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }

    indicator: Rectangle {
        antialiasing: true
        implicitWidth: 20
        implicitHeight: 20
        x: control.leftPadding
        y: 5
        radius: 5
        border.color: control.checked ? control.theme.accent : (control.hovered ? control.theme.subtext : control.theme.line)
        border.width: 1
        color: control.checked ? control.theme.accent : control.theme.checkboxBg

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: control.theme.accentText
            font.pixelSize: 13
            font.weight: Font.Medium
            opacity: control.checked ? 1 : 0
            renderType: Text.CurveRendering

            Behavior on opacity {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }
        }

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }
}
