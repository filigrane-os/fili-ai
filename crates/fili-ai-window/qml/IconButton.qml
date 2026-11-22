// Square button of the header: a glyph, hover background, accessible name.
import QtQuick
import Fili.Ai

Rectangle {
    id: btn
    property string glyph
    property string tip
    property bool on: false
    signal clicked
    implicitWidth: 28
    implicitHeight: 28
    radius: Theme.radiusControl
    color: area.pressed ? Theme.surfaceActive : area.containsMouse || on ? Theme.surfaceHover : "transparent"
    Accessible.role: Accessible.Button
    Accessible.name: tip
    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: area.containsMouse ? Theme.text : Theme.textSecondary
        font { family: Theme.font; pixelSize: Theme.sizeTitle }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
