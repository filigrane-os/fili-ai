// One entry of the conversation: a message of the user, an answer, a tool call, a note, an error or a permission asked.
import QtQuick
import QtQuick.Layouts
import Fili.Ai

Item {
    id: bubble
    required property var modelData
    readonly property bool isUser: modelData.kind === "user"
    readonly property bool isAsk: modelData.kind === "ask"
    readonly property bool quiet: modelData.kind === "tool" || modelData.kind === "note"
    width: ListView.view ? ListView.view.width : 300
    implicitHeight: card.height + Theme.space2

    Rectangle {
        id: card
        width: Math.min(parent.width - Theme.space4, Math.max(label.implicitWidth, ask.visible ? ask.implicitWidth : 0) + Theme.space4)
        x: bubble.isUser ? parent.width - width - Theme.space2 : Theme.space2
        height: col.implicitHeight + Theme.space3
        radius: Theme.radiusControl
        color: bubble.isUser ? Theme.surfaceHover : bubble.isAsk ? Theme.surface : "transparent"
        border { width: bubble.isAsk ? Theme.borderWidth : 0; color: Theme.warning }

        ColumnLayout {
            id: col
            x: Theme.space2
            y: Theme.space1 + 2
            width: parent.width - Theme.space4
            spacing: Theme.space1
            Text {
                id: label
                Layout.fillWidth: true
                text: bubble.isAsk ? (modelData.name ? modelData.name + ": " : "") + modelData.text : modelData.text
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: modelData.kind === "error" ? Theme.danger : bubble.quiet ? Theme.muted : Theme.text
                font { family: bubble.quiet ? Theme.mono : Theme.font; pixelSize: bubble.quiet ? Theme.sizeSmall : Theme.size; italic: modelData.kind === "note" }
            }
            RowLayout {
                id: ask
                visible: bubble.isAsk && modelData.status === "pending"
                spacing: Theme.space2
                Repeater {
                    model: [{ t: qsTr("Allow"), v: true }, { t: qsTr("Deny"), v: false }]
                    Rectangle {
                        required property var modelData
                        implicitWidth: btn.implicitWidth + Theme.space4
                        implicitHeight: 26
                        radius: Theme.radiusControl
                        color: hit.containsMouse ? Theme.surfaceHover : Theme.background
                        border { width: Theme.borderWidth; color: Theme.border }
                        Text { id: btn; anchors.centerIn: parent; text: parent.modelData.t; color: Theme.text; font { family: Theme.font; pixelSize: Theme.sizeList } }
                        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: Chat.answer(bubble.modelData.rid, parent.modelData.v) }
                    }
                }
            }
            Text {
                visible: bubble.isAsk && modelData.status !== "pending"
                text: modelData.status === "allowed" || modelData.status === "allow" ? qsTr("Allowed") : qsTr("Denied")
                color: Theme.muted
                font { family: Theme.font; pixelSize: Theme.sizeSmall }
            }
        }
    }
}
