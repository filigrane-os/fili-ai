pragma Singleton
// State of the conversation, driven by the events of the daemon (protocol: crates/fili-ai-daemon/src/main.rs).
// Ported from the FiliAi.qml of the shell: sessions, the log of the current one, the answer being written, the
// permissions asked. Nothing here draws anything.
import QtQuick
import Fili.Ai

QtObject {
    id: chat
    property var sessions: []
    property string current: ""
    property var items: ({})
    property var states: ({})
    property string live: ""
    property string pending: ""
    property bool agentOk: true
    // Sessions whose turn finished while another one was shown
    property var unread: ({})
    property bool tabsOpen: true
    // Archive being confirmed (session id), "" = none
    property string confirmId: ""
    // View: "dock" (windows shrink beside the drawer) or "float" (above them), and the width. Kept in the state file
    // "MODE WIDTH" (shared with the former drawer), else the defaults of fili-ai.toml, else dock 440
    readonly property string stateHome: Link.env("XDG_STATE_HOME") || Link.env("HOME") + "/.local/state"
    readonly property string configHome: Link.env("XDG_CONFIG_HOME") || Link.env("HOME") + "/.config"
    readonly property string viewFile: stateHome + "/filigrane/chat-view"
    readonly property string cfgFile: configHome + "/filigrane/fili-ai.toml"
    property string mode: "dock"
    property int viewWidth: 440
    function loadView() {
        const cfg = {};
        for (const l of Link.readText(cfgFile).split("\n")) {
            const m = l.replace(/#.*/, "").match(/^\s*(\w+)\s*=\s*"?([^"\s]*)"?\s*$/);
            if (m)
                cfg[m[1]] = m[2];
        }
        const st = Link.readText(viewFile).trim().split(/\s+/);
        const mode = st[0] || cfg.mode;
        const width = parseInt(st[1]) || parseInt(cfg.width);
        chat.mode = mode === "float" ? "float" : "dock";
        chat.viewWidth = clampWidth(width || 440);
    }
    function clampWidth(w) {
        return Math.max(300, Math.min(900, w));
    }
    function saveView() {
        Link.writeText(viewFile, mode + " " + viewWidth + "\n");
    }
    property var queued: ({})
    // Rail: the 20 most recent sessions (the current one replaces the last when it is older)
    readonly property var tabSessions: {
        const t = sessions.slice(0, 20);
        const cur = sessions.find(x => x.id === current);
        if (cur && !t.includes(cur))
            t[t.length - 1] = cur;
        return t;
    }
    readonly property var log: items[current] ?? []
    readonly property bool working: (states[current] ?? "idle") !== "idle"
    readonly property bool linked: Link.connected
    readonly property string title: sessions.find(s => s.id === current)?.title || qsTr("New session")
    readonly property bool waiting: log.some(i => i.kind === "ask" && i.status === "pending")

    function send_(obj) {
        Link.write(JSON.stringify(obj));
    }
    // Connects, starting the daemon when nobody listens
    property int tries: 0
    function connectNow() {
        if (Link.open()) {
            retry.stop();
            send_({ op: "agent" });
            if (current)
                send_({ op: "open", id: current });
            return;
        }
        if (tries === 0)
            Link.spawn("fili-ai-daemon", "daemon");
        if (++tries > 40)
            retry.stop();
        else if (!retry.running)
            retry.start();
    }
    property Timer retry: Timer {
        interval: 250
        repeat: true
        onTriggered: chat.connectNow()
    }
    function newSession() {
        send_({ op: "new" });
    }
    function send(text) {
        const t = text.trim();
        if (!t)
            return;
        if (!current) {
            pending = t;
            send_({ op: "new" });
            return;
        }
        send_({ op: "send", id: current, text: t });
    }
    function answer(rid, allow) {
        send_({ op: "answer", rid, allow });
    }
    function stop() {
        if (current)
            send_({ op: "stop", id: current });
    }
    function askArchive(id) {
        confirmId = id;
    }
    function confirmArchive(yes) {
        if (yes && confirmId)
            send_({ op: "archive", id: confirmId });
        confirmId = "";
    }
    function openSession(id) {
        const u = Object.assign({}, unread);
        delete u[id];
        unread = u;
        current = id;
        live = "";
        if (items[id] === undefined)
            send_({ op: "open", id });
    }

    function append(id, item) {
        if (items[id] === undefined)
            return;
        const m = Object.assign({}, items);
        m[id] = items[id].concat([item]);
        items = m;
    }
    function item(ev) {
        if (ev.ev === "ask")
            return { kind: "ask", rid: ev.rid, name: ev.tool, text: ev.summary, status: ev.status };
        const text = ev.ev === "tool" ? ev.summary : ev.text;
        return { kind: ev.ev === "tool" ? "tool" : ev.role, text, name: ev.name ?? "" };
    }
    function receive(ev) {
        if (ev.ev === "agent") {
            agentOk = ev.ok === true;
        } else if (ev.ev === "sessions") {
            sessions = ev.sessions.filter(s => !s.archived);
            const m = Object.assign({}, states);
            for (const s of sessions)
                m[s.id] = s.state;
            states = m;
            if (!sessions.some(s => s.id === current)) {
                current = pending ? current : (sessions[0]?.id ?? "");
                if (current && items[current] === undefined)
                    send_({ op: "open", id: current });
            }
        } else if (ev.ev === "created") {
            const m = Object.assign({}, items);
            m[ev.id] = [];
            items = m;
            current = ev.id;
            live = "";
            if (pending) {
                const t = pending;
                pending = "";
                send_({ op: "send", id: ev.id, text: t });
            }
        } else if (ev.ev === "queue") {
            const q = Object.assign({}, queued);
            q[ev.id] = ev.items;
            queued = q;
        } else if (ev.ev === "history") {
            const m = Object.assign({}, items);
            m[ev.id] = ev.items.map(item);
            items = m;
        } else if (ev.ev === "msg" || ev.ev === "tool") {
            append(ev.id, item(ev));
            if (ev.role === "assistant" && ev.id === current)
                live = "";
        } else if (ev.ev === "ask") {
            if (items[ev.id] === undefined)
                return;
            const a = items[ev.id].slice();
            const i = a.findIndex(x => x.kind === "ask" && x.rid === ev.rid);
            if (i >= 0)
                a[i] = item(ev);
            else
                a.push(item(ev));
            const m = Object.assign({}, items);
            m[ev.id] = a;
            items = m;
        } else if (ev.ev === "delta") {
            if (ev.id === current)
                live += ev.text;
        } else if (ev.ev === "state") {
            const was = states[ev.id] ?? "idle";
            const m = Object.assign({}, states);
            m[ev.id] = ev.state;
            states = m;
            if (ev.state === "idle" && ev.id === current)
                live = "";
            if (ev.state === "idle" && was !== "idle" && ev.id !== current) {
                const u = Object.assign({}, unread);
                u[ev.id] = true;
                unread = u;
            }
        } else if (ev.ev === "note") {
            append(ev.id, { kind: "note", text: ev.code === "interrupted" ? qsTr("Interrupted") : ev.code, name: "" });
        }
    }
    property Connections feed: Connections {
        target: Link
        function onLine(text) {
            try {
                chat.receive(JSON.parse(text));
            } catch (e) {}
        }
        function onConnectedChanged() {
            if (!Link.connected && chat.tries < 40)
                chat.connectNow();
        }
    }
}
