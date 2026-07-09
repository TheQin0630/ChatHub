import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    required property var theme

    textRole: "topic"
    implicitHeight: 44
    font.pixelSize: 14
    hoverEnabled: true

    contentItem: Text {
        leftPadding: 16
        rightPadding: 48
        text: control.displayText
        color: control.enabled ? control.theme.comboText : control.theme.muted
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Rectangle {
        width: 28
        height: 28
        radius: 14
        x: control.width - width - 8
        y: control.height / 2 - height / 2
        color: control.enabled ? control.theme.accent : control.theme.buttonDisabledBg
        opacity: control.enabled ? 1 : 0.7
        scale: control.pressed ? 0.92 : 1

        Rectangle {
            width: 12
            height: 2
            radius: 1
            anchors.centerIn: parent
            color: control.theme.accentText
        }

        Rectangle {
            width: 2
            height: 12
            radius: 1
            anchors.centerIn: parent
            color: control.theme.accentText
        }

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
    }

    background: Rectangle {
        radius: height / 2
        color: control.enabled ? (control.hovered || control.popup.visible ? control.theme.comboHoverBg : control.theme.comboBg) : control.theme.fieldDisabledBg
        border.color: control.activeFocus || control.popup.visible ? control.theme.accent : control.theme.fieldBorder
        border.width: control.activeFocus || control.popup.visible ? 2 : 1

        Behavior on color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
    }

    popup: Popup {
        y: control.height + 8
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
        padding: 6
        background: Rectangle {
            radius: 18
            color: control.theme.comboPopupBg
            border.color: control.theme.line
            border.width: 1
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }
    }

    delegate: ItemDelegate {
        width: control.width - 12
        height: 38
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: model.topic
            color: control.theme.comboText
            font.pixelSize: 14
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 12
            color: highlighted ? control.theme.popupHighlight : "transparent"

            Behavior on color {
                ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }
}
