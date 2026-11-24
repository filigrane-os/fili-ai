// "About Lia": the card every fili-* application has (display name, "Also known as" the program, then the useful facts:
// agent, version and model read by `fili-ai status` at every opening, sessions, view, settings file). In the middle of the
// screen over a dimmed overlay (the kit's FiliAboutCard); Escape, Enter or a click outside close it.
import QtQuick
import QtQuick.Window
import org.kde.layershell 1.0 as LayerShell
import Fili.Ai
import Fili.UI

Window {
    id: about
    property bool shown: false
    property var info: ({ agent: "", model: "", version: "" })
    visible: shown
    width: Screen.width
    height: Screen.height
    color: "transparent"
    title: "Lia"

    LayerShell.Window.scope: "fili-ai-about"
    LayerShell.Window.layer: LayerShell.Window.LayerOverlay
    LayerShell.Window.anchors: LayerShell.Window.AnchorTop | LayerShell.Window.AnchorBottom | LayerShell.Window.AnchorLeft | LayerShell.Window.AnchorRight
    LayerShell.Window.exclusionZone: -1
    LayerShell.Window.keyboardInteractivity: LayerShell.Window.KeyboardInteractivityOnDemand

    readonly property var rows: [
        [Link.tr("Also known as"), "fili-ai"],
        [Link.tr("Part of"), "Filigrane"],
        [Link.tr("Version"), Link.version()],
        [Link.tr("Agent"), (info.agent || "—") + (info.version ? " " + info.version : "")],
        [Link.tr("Model"), info.model || Link.tr("default")],
        [Link.tr("Sessions"), String(Chat.sessions.length)],
        [Link.tr("View"), (Chat.mode === "dock" ? Link.tr("Dock Beside Windows") : Link.tr("Float Above Windows")) + " · " + Chat.viewWidth + " px"],
        [Link.tr("Follow"), Chat.follow],
        [Link.tr("Settings"), "~/.config/filigrane/fili-ai.toml"]
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

    // The kit's card, over the whole screen: its own scrim, Esc, Enter or a click outside close it
    FiliAboutCard {
        id: card
        appName: "Lia"
        tagline: Link.tr("The assistant of Filigrane")
        iconSource: { const f = Link.iconPath("fili-ai"); return f !== "" ? "file://" + f : ""; }
        rows: about.rows
        onVisibleChanged: if (!visible) about.shown = false
    }
    onShownChanged: shown ? card.open() : card.close()
}
