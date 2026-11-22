// "About Lia": the card every fili-* application has (display name, "Also known as" the program, then the useful facts:
// agent, version and model read by `fili-ai status` at every opening, sessions, view, settings file). In the middle of the
// screen over a dimmed overlay; Escape, a key or a click outside close it.
import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import org.kde.layershell 1.0 as LayerShell
import Fili.Ai

Window {
    id: about
    property bool shown: false
    property var info: ({ agent: "", model: "", version: "" })
    visible: shown
    width: Screen.width
    height: Screen.height
    color: "#99101419"
    title: "Lia"

    LayerShell.Window.scope: "fili-ai-about"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    readonly property var rows: [
        [qsTr("Also known as"), "fili-ai"],
        [qsTr("Part of"), "Filigrane"],
        [qsTr("Version"), Link.version()],
        [qsTr("Agent"), (info.agent || "—") + (info.version ? " " + info.version : "")],
        [qsTr("Model"), info.model || qsTr("default")],
        [qsTr("Sessions"), String(Chat.sessions.length)],
        [qsTr("View"), (Chat.mode === "dock" ? qsTr("Dock Beside Windows") : qsTr("Float Above Windows")) + " · " + Chat.viewWidth + " px"],
        [qsTr("Follow"), Chat.follow],
        [qsTr("Settings"), "~/.config/filigrane/fili-ai.toml"]
    ]
    function open() {
        // `fili-ai status`: agent, model and version, read once per opening
        const lines = Link.capture("fili-ai status 2>/dev/null").split("\n");
        const field = k => (lines.find(l => l.startsWith(k + ":")) ?? "").slice(k.length + 1).trim();
        const agent = field("Agent");
        const nice = /\((.*)\)\s*$/.exec(agent);
        const key = agent.split(" ")[0];
        const inst = lines.find(l => /^\s+\S+ \S+/.test(l) && l.trim().startsWith(key + " "));
        info = { agent: nice ? nice[1] : agent, model: field("Model") === "default" ? "" : field("Model"), version: inst ? inst.trim().split(" ")[1] : "" };
        shown = true;
    }
    function close() {
        shown = false;
    }

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: about.close() }
    FocusScope {
        anchors.fill: parent
        focus: about.shown
        Keys.onPressed: e => about.close()
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 400)
            height: Math.min(parent.height - 48, content.implicitHeight + 48)
            color: Theme.background
            border { color: Theme.border; width: Theme.borderWidth }
            radius: Theme.radiusWindow
            clip: true
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space4 + Theme.space2 }
                spacing: Theme.space3
                Text { Layout.alignment: Qt.AlignHCenter; text: String.fromCodePoint(0xf06a9); color: Theme.working; font { family: Theme.icons; pixelSize: 64 } }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Lia"; color: Theme.text; font { family: Theme.font; pixelSize: 28; weight: Theme.weightAccent } }
                Text { Layout.alignment: Qt.AlignHCenter; text: qsTr("The assistant of Filigrane"); color: Theme.textSecondary; font { family: Theme.font; pixelSize: Theme.size; weight: Font.Light } }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: Theme.space2; implicitHeight: 1; color: Theme.border }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 3
                    Repeater {
                        model: about.rows.reduce((a, r) => a.concat([{ t: r[0], key: true }, { t: r[1], key: false }]), [])
                        Text {
                            required property var modelData
                            text: modelData.t
                            color: modelData.key ? Theme.textSecondary : Theme.text
                            Layout.preferredWidth: modelData.key ? 130 : -1
                            Layout.fillWidth: !modelData.key
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: Theme.size }
                        }
                    }
                }
                Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: Theme.space1; text: qsTr("Esc to close"); color: Theme.muted; font { family: Theme.font; pixelSize: Theme.sizeList } }
            }
        }
    }
}
