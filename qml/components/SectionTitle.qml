import QtQuick
import QtQuick.Controls.Basic

Label {
    required property var theme
    color: theme.text
    font.pixelSize: 14
    font.weight: Font.Medium
    renderType: Text.CurveRendering
}
