import QtQuick

Item {
    id: root
    required property var theme

    implicitWidth: 44
    implicitHeight: 44

    Rectangle {
        antialiasing: true
        anchors.fill: parent
        radius: 14
        color: "#fff7ef"
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
        anchors.fill: parent
        anchors.margins: 1
        source: "image://appicons/logo"
        sourceClipRect: Qt.rect(9, 10, 110, 108)
        fillMode: Image.PreserveAspectFit
        cache: true
        smooth: true
        mipmap: true
        sourceSize.width: 128
        sourceSize.height: 128
    }
}
