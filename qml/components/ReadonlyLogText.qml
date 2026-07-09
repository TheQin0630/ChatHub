import QtQuick
import QtQuick.Controls.Basic

Label {
    required property var theme
    color: theme.subtext
    font.pixelSize: 11
    font.family: "Consolas"
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    maximumLineCount: 1
}
