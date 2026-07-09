import QtQuick
import QtQuick.Controls.Basic

CheckBox {
    id: control
    required property var theme
    property string description: ""

    font.pixelSize: 14
    spacing: 9
    hoverEnabled: true
    implicitHeight: Math.max(32, checkContent.implicitHeight)

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
        }

        Text {
            width: Math.max(0, control.width - control.indicator.width - control.spacing)
            text: control.checked ? control.description : ""
            visible: text.length > 0
            opacity: control.checked ? 1 : 0
            color: control.theme.subtext
            font.pixelSize: 11
            wrapMode: Text.WordWrap

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
        }
    }

    indicator: Rectangle {
        implicitWidth: 24
        implicitHeight: 24
        x: control.leftPadding
        y: 4
        radius: width / 2
        border.color: control.checked ? control.theme.accent : (control.hovered ? control.theme.subtext : control.theme.line)
        border.width: control.checked ? 0 : 1
        color: control.checked ? control.theme.accent : control.theme.checkboxBg

        Item {
            anchors.centerIn: parent
            width: 13
            height: 10
            opacity: control.checked ? 1 : 0
            scale: control.checked ? 1 : 0.45

            Rectangle {
                width: 5
                height: 2
                radius: 1
                color: control.theme.accentText
                x: 1
                y: 6
                rotation: 45
            }

            Rectangle {
                width: 10
                height: 2
                radius: 1
                color: control.theme.accentText
                x: 4
                y: 5
                rotation: -45
            }

            Behavior on opacity {
                NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
            }

            Behavior on scale {
                NumberAnimation { duration: 180; easing.type: Easing.OutBack }
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
