import QtQuick
import QtQuick.Controls.Basic

Label {
    required property var theme
    color: theme.text
    font.pixelSize: 15
    font.weight: Font.DemiBold
}
