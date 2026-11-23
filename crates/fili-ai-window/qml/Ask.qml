// The small floating field of "Ask Lia…" (Mod+Ctrl+Y, the entry of every application menu): a line to ask about the active
// application without opening the drawer. The application is the one noted by `fili-ai here` (context.json); the session
// scoped to it gets the question (Chat.askHere). Enter = send and open the drawer on the new session, Shift+Enter = send and
// stay where you are (a notification says when Lia has finished), Escape or a click outside = close (the draft is kept).
// Without an application in the context an ordinary drawer opens.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import Fili.Ai
import Fili.UI

Window {
    id: ask
    property bool shown: false
    property string appId: ""
    visible: shown
    width: Screen.width
    height: Screen.height
    color: "transparent"
    title: "Lia"

    LayerShell.Window.scope: "fili-ask"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityExclusive

    function open() {
        Chat.readContext();
        appId = Chat.ctx?.window?.app_id ?? "";
        // No application (empty desktop): the drawer, as for any question
        if (appId)
            shown = true;
        else
            Chat.show();
    }
    function close() {
        shown = false;
    }
    function submit(drawer) {
        const t = input.text.trim();
        if (!t)
            return;
        close();
        input.text = "";
        Chat.askHere(t, drawer);
    }
    onShownChanged: if (shown) input.forceActiveFocus()

    MouseArea { anchors.fill: parent; onPressed: ask.close() }
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.round(parent.height * 0.18) }
        width: Math.min(parent.width - 2 * FiliTheme.space4, 520)
        height: col.implicitHeight + 2 * FiliTheme.space4
        color: FiliTheme.background
        border { color: FiliTheme.border; width: FiliTheme.borderWidth }
        radius: FiliTheme.radiusWindow
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: FiliTheme.space4 }
            spacing: FiliTheme.space2
            RowLayout {
                Layout.fillWidth: true
                spacing: FiliTheme.space2
                Text { text: String.fromCodePoint(0xf06a9); color: LiaTheme.working; font { family: FiliTheme.icons; pixelSize: 16 } }
                Text {
                    Layout.fillWidth: true
                    text: ask.appId ? Link.tr("Lia, about %1").replace("%1", ask.appId) : "Lia"
                    elide: Text.ElideRight
                    color: FiliTheme.textSecondary
                    font { family: FiliTheme.font; pixelSize: FiliTheme.sizeSmall; weight: FiliTheme.weightAccent }
                }
            }
            TextInput {
                id: input
                Layout.fillWidth: true
                color: FiliTheme.text
                selectionColor: FiliTheme.surfaceHover
                selectedTextColor: FiliTheme.text
                font { family: FiliTheme.font; pixelSize: FiliTheme.size + 2; weight: Font.Light }
                clip: true
                Text {
                    visible: !input.text
                    text: Link.tr("Ask anything about this application…")
                    color: FiliTheme.muted
                    font: input.font
                    elide: Text.ElideRight
                    width: parent.width
                }
                Keys.onPressed: k => {
                    if (k.key === Qt.Key_Escape) {
                        ask.close();
                    } else if (k.key === Qt.Key_Return || k.key === Qt.Key_Enter) {
                        ask.submit(!(k.modifiers & Qt.ShiftModifier));
                        k.accepted = true;
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: Link.tr("Enter to send · Shift+Enter to send without opening the drawer · Esc to cancel")
                elide: Text.ElideRight
                color: FiliTheme.muted
                font { family: FiliTheme.font; pixelSize: FiliTheme.sizeSmall }
            }
        }
    }
}
