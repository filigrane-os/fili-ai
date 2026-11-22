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
    property var queued: ({})
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
    function openSession(id) {
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
            const m = Object.assign({}, states);
            m[ev.id] = ev.state;
            states = m;
            if (ev.state === "idle" && ev.id === current)
                live = "";
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
