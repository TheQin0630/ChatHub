import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control
    required property var theme

    textRole: "topic"
    implicitHeight: 38
    font.pixelSize: 13
    font.weight: Font.Normal
    hoverEnabled: true

    contentItem: Text {
        leftPadding: 14
        rightPadding: 48
        text: control.displayText
        color: control.enabled ? control.theme.comboText : control.theme.muted
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        renderType: Text.CurveRendering
    }

    indicator: Rectangle {
        antialiasing: true
        width: 30
        height: 30
        radius: 15
        x: control.width - width - 6
        y: control.height / 2 - height / 2
        color: control.enabled ? (control.hovered || control.popup.visible ? control.theme.accentSoft : control.theme.surfaceAlt) : control.theme.buttonDisabledBg
        border.color: control.enabled ? control.theme.glassBorder : "transparent"
        border.width: 1
        opacity: control.enabled ? 1 : 0.7

        Text {
            anchors.centerIn: parent
            text: "+"
            color: control.enabled ? control.theme.accent : control.theme.muted
            font.pixelSize: 18
            font.weight: Font.Medium
            renderType: Text.CurveRendering
        }

        Behavior on color {
            ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

    }

    background: Rectangle {
        antialiasing: true
        radius: height / 2
        color: control.enabled ? (control.hovered || control.popup.visible ? control.theme.comboHoverBg : control.theme.comboBg) : control.theme.fieldDisabledBg
        border.color: control.activeFocus || control.popup.visible ? control.theme.accent : control.theme.fieldBorder
        border.width: 1

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
            antialiasing: true
            radius: 14
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
        height: 34
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: model.topic
            color: control.theme.comboText
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            renderType: Text.CurveRendering
        }
        background: Rectangle {
            antialiasing: true
            radius: 10
            color: highlighted ? control.theme.popupHighlight : "transparent"

            Behavior on color {
                ColorAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
        }
    }
}
