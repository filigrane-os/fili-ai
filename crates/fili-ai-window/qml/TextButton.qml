// Text button (trash toolbar, status bar, confirmation): hover surfaceHover, pressed surfaceActive.
// primary: text in accentColor (default action).
import QtQuick
import Fili.Ai

Rectangle {
    id: b
    property string label
    property bool primary: false
    signal clicked()

    width: text.implicitWidth + 2 * Theme.space3
    height: 22
    radius: Theme.radiusControl
    color: area.pressed ? Theme.surfaceActive : area.containsMouse ? Theme.surfaceHover : "transparent"
    border.width: primary ? 1 : 0
    border.color: Theme.accent

    Text {
        id: text
        anchors.centerIn: parent
        text: b.label
        font.family: Theme.font
        font.pixelSize: Theme.sizeList
        color: b.primary ? Theme.accent : Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: b.clicked()
    }
}
