// Debug panel: the log of the application (src/logs.rs) in a band above the footer, opened from View > Debug Logs. The text is
// selectable (Ctrl+C copies the selection, "Copy" the selection or everything shown), a filter keeps warnings or errors, and the
// top edge is dragged to change the height. It only reads: Link.logs(since), Link.logFile(), Link.clearLogs(), Link.copyText()
// and Link.openPath(), which every fili-* application gives the same way (agents/skills/filigrane-ui/references/app-window.md).
import QtQuick
import Fili.Ai

Rectangle {
    id: panel
    property bool open: false
    // What is shown: 0 everything, 1 warnings and errors, 2 errors
    property int filter: 0
    property real panelHeight: Number(Link.uiState("debug_height")) || 220
    readonly property int keep: 2000

    visible: open
    height: open ? panelHeight : 0
    color: Theme.backgroundDeep

    // The entries received ({ level, text }) and the number of the last one
    property var entries: []
    property int seq: 0
    property int shown: 0
    // Result of "Ask Lia", shown in the header for a few seconds
    property string note: ""

    function colorOf(level) {
        return String(level >= 3 ? Theme.danger : level === 2 ? Theme.warning : level === 1 ? Theme.textSecondary : Theme.muted);
    }
    function wanted(level) {
        return filter === 0 || (filter === 1 ? level >= 2 : level >= 3);
    }
    function html(e) {
        const text = e.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return '<div style="white-space: pre-wrap; color: ' + colorOf(e.level) + '">' + text + "</div>";
    }
    function rebuild() {
        const list = entries.filter(e => wanted(e.level));
        shown = list.length;
        edit.text = list.map(html).join("");
        follow();
    }
    // Stays on the last line while the reader is there (or has nothing selected to read)
    function follow() {
        Qt.callLater(() => flick.contentY = Math.max(0, flick.contentHeight - flick.height));
    }
    function poll() {
        const r = JSON.parse(Link.logs(seq));
        seq = r.seq;
        if (r.entries.length === 0)
            return;
        const atEnd = flick.atYEnd && edit.selectionStart === edit.selectionEnd;
        const added = r.entries.map(([level, text]) => ({ level: level, text: text }));
        entries = entries.concat(added);
        if (entries.length > keep) {
            entries = entries.slice(entries.length - keep);
            rebuild();
            return;
        }
        for (const e of added) {
            if (wanted(e.level)) {
                edit.append(html(e));
                shown++;
            }
        }
        if (atEnd)
            follow();
    }
    // The problem: the lines selected in the panel, else the last ones; Lia is asked to look at it (fili-incident)
    function askLia() {
        const id = Link.reportProblem(edit.selectedText);
        note = id !== "" ? qsTr("Lia was asked to look at it") : qsTr("Could not record the problem");
        noteTimer.restart();
    }
    Timer {
        id: noteTimer
        interval: 5000
        onTriggered: panel.note = ""
    }
    function reset() {
        entries = [];
        seq = 0;
        poll();
        rebuild();
    }
    function copy() {
        Link.copyText(edit.selectedText !== "" ? edit.selectedText : edit.getText(0, edit.length));
    }
    onOpenChanged: if (open)
        reset()
    onFilterChanged: rebuild()
    Timer {
        interval: 500
        repeat: true
        running: panel.open
        onTriggered: panel.poll()
    }

    Rectangle {
        width: parent.width
        height: Theme.borderWidth
        color: Theme.border
    }
    // The top edge changes the height
    MouseArea {
        id: grip
        z: 5
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 6
        cursorShape: Qt.SizeVerCursor
        onPositionChanged: e => {
            if (!pressed)
                return;
            const y = grip.mapToItem(panel.parent, 0, e.y).y;
            const bottom = panel.y + panel.height;
            panel.panelHeight = Math.max(100, Math.min(panel.parent.height * 0.7, bottom - y));
        }
        onReleased: Link.setUiState("debug_height", String(Math.round(panel.panelHeight)))
    }

    // Header: wraps on a narrow drawer (title and filters, then the actions)
    Item {
        id: head
        y: Theme.borderWidth
        width: parent.width
        height: bar.height + Theme.space1 * 2
        Flow {
            id: bar
            x: Theme.space3
            y: Theme.space1
            width: parent.width - 2 * Theme.space3
            spacing: Theme.space1
            Text {
                height: 22
                verticalAlignment: Text.AlignVCenter
                rightPadding: Theme.space2
                text: qsTr("Debug logs")
                font.family: Theme.font
                font.pixelSize: Theme.size
                font.weight: Theme.weightAccent
                color: Theme.text
            }
            Repeater {
                model: [qsTr("All"), qsTr("Warnings"), qsTr("Errors")]
                TextButton {
                    required property string modelData
                    required property int index
                    label: modelData
                    primary: panel.filter === index
                    onClicked: panel.filter = index
                }
            }
            Text {
                height: 22
                verticalAlignment: Text.AlignVCenter
                leftPadding: Theme.space2
                text: panel.note !== "" ? panel.note : panel.shown + " " + qsTr("entries")
                font.family: Theme.font
                font.pixelSize: Theme.sizeSmall
                color: panel.note !== "" ? Theme.accent : Theme.muted
            }
            TextButton { label: qsTr("Ask Lia"); onClicked: panel.askLia() }
            TextButton { label: qsTr("Copy"); onClicked: panel.copy() }
            TextButton {
                label: qsTr("Clear")
                onClicked: {
                    Link.clearLogs();
                    panel.reset();
                }
            }
            TextButton { label: qsTr("Open file"); onClicked: Link.openPath(Link.logFile()) }
            TextButton { label: "×"; onClicked: panel.open = false }
        }
    }

    Flickable {
        id: flick
        anchors { top: head.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space3; rightMargin: Theme.space3; bottomMargin: Theme.space1 }
        contentWidth: width
        contentHeight: edit.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        KineticScroll {}
        TextEdit {
            id: edit
            width: flick.width - 10
            readOnly: true
            selectByMouse: true
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.Wrap
            font.family: Theme.mono
            font.pixelSize: Theme.sizeSmall
            color: Theme.textSecondary
            selectionColor: Theme.accent
            selectedTextColor: "white"
        }
    }
    FiliScrollBar {
        flick: flick
        anchors { top: flick.top; bottom: flick.bottom; right: flick.right }
    }
    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("Debug logs")
}
