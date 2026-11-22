// Entry of the application: the drawer and the small floating field are two windows side by side (a window declared
// inside another would be its child and stay hidden), driven by the commands of Chat (`fili-ai toggle|show|here|...`).
import QtQuick
import Fili.Ai

QtObject {
    id: root
    property Window drawer: Drawer {}
    property Window field: Ask {}

    property Connections wiring: Connections {
        target: Chat
        function onFieldRequested() { root.field.open(); }
        function onFieldClosed() { root.field.close(); }
    }
    property Connections commands: Connections {
        target: Link
        function onCommand(text) { Chat.act(text); }
    }
    // The application lives while the drawer is shown or an agent works for it; then it ends (the daemon stops by itself)
    property Timer lifetime: Timer {
        interval: 600
        running: !Chat.wantLink && !root.field.shown
        onTriggered: Qt.quit()
    }
    Component.onCompleted: {
        Chat.loadView();
        Link.watchTheme();
        Link.serveCommands();
        Chat.act(Link.initialCommand());
    }
}
