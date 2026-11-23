// One entry of the conversation: a message of the user, an answer, a tool call, a note, an error or a permission asked.
import QtQuick
import QtQuick.Layouts
import Fili.Ai
import Fili.UI

Item {
    id: bubble
    required property var modelData
    readonly property bool isUser: modelData.kind === "user"
    readonly property bool isAsk: modelData.kind === "ask"
    readonly property bool quiet: modelData.kind === "tool" || modelData.kind === "note"
    width: ListView.view ? ListView.view.width : 300
    implicitHeight: card.height + FiliTheme.space2

    Rectangle {
        id: card
        width: Math.min(parent.width - FiliTheme.space4, Math.max(label.implicitWidth, ask.visible ? ask.implicitWidth : 0) + FiliTheme.space4)
        x: bubble.isUser ? parent.width - width - FiliTheme.space2 : FiliTheme.space2
        height: col.implicitHeight + FiliTheme.space3
        radius: FiliTheme.radiusControl
        color: bubble.isUser ? FiliTheme.surfaceHover : bubble.isAsk ? FiliTheme.surface : "transparent"
        border { width: bubble.isAsk ? FiliTheme.borderWidth : 0; color: FiliTheme.warning }

        ColumnLayout {
            id: col
            x: FiliTheme.space2
            y: FiliTheme.space1 + 2
            width: parent.width - FiliTheme.space4
            spacing: FiliTheme.space1
            // Read-only text edit: the text can be selected with the mouse (Ctrl+C copies it, see Drawer.qml). It does not take the
            // keyboard focus: the field of the message keeps it
            TextEdit {
                id: label
                Layout.fillWidth: true
                readOnly: true
                selectByMouse: true
                activeFocusOnPress: false
                selectionColor: FiliTheme.accentColor
                selectedTextColor: FiliTheme.background
                onSelectedTextChanged: if (selectedText !== "") Chat.picked = selectedText
                text: bubble.isAsk ? (modelData.name ? modelData.name + ": " : "") + modelData.text : modelData.text
                textFormat: TextEdit.PlainText
                wrapMode: TextEdit.Wrap
                color: modelData.kind === "error" ? FiliTheme.danger : bubble.quiet ? FiliTheme.muted : FiliTheme.text
                font { family: bubble.quiet ? FiliTheme.mono : FiliTheme.font; pixelSize: bubble.quiet ? FiliTheme.sizeSmall : FiliTheme.size; italic: modelData.kind === "note" }
            }
            RowLayout {
                id: ask
                visible: bubble.isAsk && modelData.status === "pending"
                spacing: FiliTheme.space2
                Repeater {
                    model: [{ t: Link.tr("Allow"), v: true }, { t: Link.tr("Deny"), v: false }]
                    Rectangle {
                        required property var modelData
                        implicitWidth: btn.implicitWidth + FiliTheme.space4
                        implicitHeight: 26
                        radius: FiliTheme.radiusControl
                        color: hit.containsMouse ? FiliTheme.surfaceHover : FiliTheme.background
                        border { width: FiliTheme.borderWidth; color: FiliTheme.border }
                        Text { id: btn; anchors.centerIn: parent; text: parent.modelData.t; color: FiliTheme.text; font { family: FiliTheme.font; pixelSize: FiliTheme.sizeList } }
                        MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true; onClicked: Chat.answer(bubble.modelData.rid, parent.modelData.v) }
                    }
                }
            }
            Text {
                visible: bubble.isAsk && modelData.status !== "pending"
                text: modelData.status === "allowed" || modelData.status === "allow" ? Link.tr("Allowed") : Link.tr("Denied")
                color: FiliTheme.muted
                font { family: FiliTheme.font; pixelSize: FiliTheme.sizeSmall }
            }
        }
    }
}
