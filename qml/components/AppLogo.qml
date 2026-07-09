import QtQuick

Item {
    id: root
    required property var theme

    implicitWidth: 42
    implicitHeight: 42

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: root.theme.surfaceAlt
        border.color: root.theme.line
        border.width: 1

        Behavior on color {
            ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        Behavior on border.color {
            ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
        }
    }

    Image {
        anchors.centerIn: parent
        width: 36
        height: 36
        source: "qrc:/icons/my_icon_light_ui.png"
        fillMode: Image.PreserveAspectFit
        cache: true
        smooth: true
        mipmap: true
        sourceSize.width: 96
        sourceSize.height: 96
    }
}
