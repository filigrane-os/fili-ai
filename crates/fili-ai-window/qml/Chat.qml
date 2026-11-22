pragma Singleton
// State of the conversation, driven by the events of the daemon (protocol: crates/fili-ai-daemon/src/main.rs).
// Ported from the FiliAi.qml of the shell: sessions, the log of the current one, the answer being written, the
// permissions asked. Nothing here draws anything.
import QtQuick
import Fili.Ai

QtObject {
    id: chat
    // Tests (`fili-ai-window --test`, qml/TestMain.qml): nothing leaves the process; what would have been sent to the daemon,
    // run as a command or written for the shell is kept in these lists instead
    property bool testing: false
    property var sent: []
    property var ran: []
    property var published: []
    property var sessions: []
    // All the sessions, archived ones included (the list of the rail footer)
    property var allSessions: []
    property bool allOpen: false
    property bool renaming: false
    property string current: ""
    property var items: ({})
    property var states: ({})
    property string live: ""
    property string pending: ""
    property bool agentOk: true
    // Sessions whose turn finished while another one was shown
    property var unread: ({})
    property bool tabsOpen: true
    property bool debugOpen: false
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
        chat.follow = cfg.follow === "window" || cfg.follow === "off" ? cfg.follow : "app";
        chat.mode = mode === "float" ? "float" : "dock";
        chat.viewWidth = clampWidth(width || 440);
    }
    // ───── window state ─────
    property bool open: false
    property bool focused: false
    // Sessions whose answer is unread / permission asked: attention for the bar ("waiting", "done", "")
    readonly property bool busy: Object.keys(states).some(k => states[k] !== "idle")
    readonly property string attention: Object.keys(states).some(k => states[k] === "waiting") ? "waiting" : Object.keys(unread).length ? "done" : ""
    // The application noted by `fili-ai toggle|here|ask` (fili-context): chip above the input, attached to the next message
    property var ctx: null
    property bool ctxOn: false
    readonly property string ctxLabel: ctx ? [ctx.window?.app_id, ctx.window?.title].filter(x => x).join(" · ") : ""
    readonly property string ctxFile: stateHome + "/filigrane/context.json"
    property string follow: "app"
    property bool followPending: false
    property bool ctxReady: false
    property bool sessionsFresh: false
    property string pendingLink: ""
    property string pendingAsk: ""
    property bool hereWant: false
    property string hereText: ""
    property bool pendingScope: false
    // A question sent from the floating field keeps the link until the agent starts working
    property bool awaiting: false
    signal focusInput
    signal fieldRequested
    signal fieldClosed
    signal aboutRequested

    function readContext() {
        if (testing) {
            ctxReady = true;
            return;
        }
        let c = null;
        try {
            c = JSON.parse(Link.readText(ctxFile));
        } catch (e) {}
        ctx = c && c.window && c.window.app_id ? c : null;
        ctxOn = ctx !== null;
        ctxReady = true;
    }
    // Key of the session <-> application link; "" without an application. force: even with follow = "off"
    function linkKey(c, force) {
        const id = c?.window?.app_id;
        if (!id || (follow === "off" && !force))
            return "";
        return follow === "window" ? id + "\n" + (c.window.title ?? "") : id;
    }
    function tryFollow() {
        if (!followPending || !ctxReady || !sessionsFresh)
            return;
        followPending = false;
        const key = linkKey(ctx);
        if (!key || working)
            return;
        const s = sessions.find(x => x.link === key);
        if (s && s.id !== current)
            openSession(s.id);
    }
    function markRead() {
        if (!unread[current])
            return;
        const u = Object.assign({}, unread);
        delete u[current];
        unread = u;
    }
    function show() {
        if (!open) {
            followPending = true;
            ctxReady = false;
            sessionsFresh = linked;
        }
        open = true;
        markRead();
        readContext();
        connectNow();
        tryFollow();
        askNow();
        hereNow();
        focusInput();
    }
    function hide() {
        open = false;
    }
    function toggle() {
        open ? hide() : show();
    }
    function ask(text) {
        if (!text)
            return;
        show();
        followPending = false;
        pendingAsk = text;
        askNow();
    }
    function askNow() {
        if (!pendingAsk || !ctxReady || !linked)
            return;
        pending = pendingAsk;
        pendingAsk = "";
        send_({ op: "new" });
    }
    // "Ask Lia" of an application: the session scoped to it is created and linked, TEXT is sent if given. Without a
    // text, the small floating field asks it
    function here(text) {
        if (!text) {
            fieldRequested();
            return;
        }
        show();
        followPending = false;
        hereWant = true;
        hereText = text;
        hereNow();
    }
    // From the floating field: the drawer stays closed unless `drawer`
    function askHere(text, drawer) {
        if (drawer) {
            here(text);
            return;
        }
        followPending = false;
        hereWant = true;
        hereText = text;
        awaiting = true;
        awaitingTimer.restart();
        ctxReady = false;
        sessionsFresh = linked;
        readContext();
        connectNow();
        hereNow();
    }
    function hereNow() {
        if (!hereWant || !ctxReady || !sessionsFresh)
            return;
        hereWant = false;
        const text = hereText;
        hereText = "";
        const key = linkKey(ctx, true);
        if (!key) {
            if (text)
                ask(text);
            return;
        }
        pendingLink = key;
        pendingScope = true;
        pending = text;
        send_({ op: "new" });
    }
    property Timer awaitingTimer: Timer {
        interval: 30000
        onTriggered: chat.awaiting = false
    }
    // The window stays alive only while shown, or while an agent works for it
    readonly property bool wantLink: open || busy || awaiting

    // Commands (command line, bar menu, notifications): `act NAME ARGS`
    function act(line) {
        const words = line.trim().split(/\s+/);
        const a = words[0];
        const args = words.slice(1);
        const rest = args.join(" ");
        switch (a) {
        case "show": show(); break;
        case "toggle": toggle(); break;
        case "close": case "hide": hide(); fieldClosed(); break;
        case "open": show(); if (args[0]) openSession(args[0]); break;
        case "new": show(); newSession(); break;
        case "ask": ask(rest); break;
        case "here": here(rest); break;
        case "new-here": show(); pendingLink = linkKey(ctx, true); newSession(); break;
        case "unlink": if (current) send_({ op: "link", id: current, key: "" }); break;
        case "sessions": show(); tabsOpen = !tabsOpen; break;
        case "rename": show(); startRename(); break;
        case "about": aboutRequested(); break;
        case "debug": show(); debugOpen = !debugOpen; break;
        case "settings": openSettings(); break;
        case "stop": stop(); break;
        case "archive": show(); askArchive(current); break;
        case "allow": answerFirst(true); break;
        case "deny": answerFirst(false); break;
        case "drop-context": ctxOn = false; break;
        case "float": setMode("float"); break;
        case "dock": setMode("dock"); break;
        case "width-narrow": setWidth(360); break;
        case "width-medium": setWidth(440); break;
        case "width-wide": setWidth(560); break;
        case "answer": if (args[0]) answerArg(args[0]); break;
        }
    }
    function setMode(m) {
        mode = m;
        saveView();
    }
    function setWidth(w) {
        viewWidth = clampWidth(w);
        saveView();
    }
    function answerArg(a) {
        const i = a.lastIndexOf(":");
        if (i > 0)
            answer(a.slice(0, i), a.slice(i + 1) === "yes");
    }
    function answerFirst(allow) {
        const a = log.find(i => i.kind === "ask" && i.status === "pending");
        if (a)
            answer(a.rid, allow);
    }

    // ───── notifications (notify-send; the shell shows them) ─────
    // Allow / Deny answer through `fili-ai act answer`, the default action (a click) opens the session
    function runDetached(script, args) {
        if (testing) {
            ran = ran.concat([args.join(" | ")]);
            return;
        }
        Link.spawn("setsid", ["-f", "sh", "-c", script, "fili-ai"].concat(args).join("\u001f"));
    }
    function sessionTitle(id) {
        return sessions.find(s => s.id === id)?.title || "Lia";
    }
    function notifyAsk(id, rid, tool, summary) {
        runDetached('r="$(notify-send -a fili-ai -i fili-ai -u critical -t 120000 -h "string:x-fili-ai-rid:$2" -A allow="$5" -A deny="$6" -A default="$7" "$3" "$4")"\n'
                    + 'case "$r" in allow) exec "$0" act answer "$2:yes" ;; deny) exec "$0" act answer "$2:no" ;; default) exec "$0" act open "$1" ;; esac',
                    [id, rid, Link.tr("Lia needs you") + " · " + sessionTitle(id), (tool ? tool + ": " : "") + summary, Link.tr("Allow"), Link.tr("Deny"), Link.tr("Open")]);
    }
    function notify(id, summary, urgency) {
        runDetached('r="$(notify-send -a fili-ai -i fili-ai -u "$2" -A default="$5" "$3" "$4")" && [ "$r" = default ] && exec "$0" act open "$1"',
                    [id, urgency, summary, sessionTitle(id), Link.tr("Open")]);
    }

    // ───── state for the shell (docs/api.md, "The assistant") ─────
    function uiJson() {
        return JSON.stringify({ v: 1, open: open, focused: focused, attention: attention, busy: busy });
    }
    function publishUi() {
        if (testing) {
            published = published.concat([uiJson()]);
            return;
        }
        const dir = Link.env("XDG_RUNTIME_DIR") || "/tmp";
        Link.writeText(dir + "/fili/ai/ui.json", uiJson());
    }
    property Timer uiTimer: Timer {
        interval: 40
        onTriggered: chat.publishUi()
    }
    onOpenChanged: uiTimer.restart()
    onFocusedChanged: uiTimer.restart()
    onAttentionChanged: uiTimer.restart()
    onBusyChanged: uiTimer.restart()

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
    // Connected to the daemon (tests: set by hand)
    property bool testLinked: false
    readonly property bool linked: testing ? testLinked : Link.connected
    readonly property string title: sessions.find(s => s.id === current)?.title || Link.tr("New session")
    readonly property bool waiting: log.some(i => i.kind === "ask" && i.status === "pending")

    function send_(obj) {
        if (testing) {
            sent = sent.concat([obj]);
            return;
        }
        Link.write(JSON.stringify(obj));
    }
    // Connects, starting the daemon when nobody listens
    property int tries: 0
    function connectNow() {
        if (testing)
            return;
        if (Link.open()) {
            retry.stop();
            send_({ op: "agent" });
            if (current)
                send_({ op: "open", id: current });
            askNow();
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
        followPending = false;
        send_({ op: "new" });
    }
    function send(text) {
        let t = text.trim();
        if (!t && !attached.length)
            return;
        if (attached.length) {
            t = (t || Link.tr("Here are some files.")) + "\n\n" + Link.tr("Attached files:") + "\n" + attached.join("\n");
            attached = [];
        }
        followPending = false;
        if (!current) {
            pending = t;
            if (ctxOn && !pendingLink)
                pendingLink = linkKey(ctx);
            send_({ op: "new" });
            return;
        }
        // First conversation with an application: the session links to it
        const cur = sessions.find(x => x.id === current);
        if (ctxOn && cur && !cur.link && linkKey(ctx))
            send_({ op: "link", id: current, key: linkKey(ctx) });
        const req = { op: "send", id: current, text: t };
        if (ctxOn)
            req.context = true;
        ctxOn = false;
        send_(req);
    }
    // Files attached to the next message (dropped, pasted)
    property var attached: []
    function attachUrls(urls) {
        const p = urls.filter(u => u.startsWith("file://")).map(u => decodeURIComponent(u.slice(7)));
        attached = attached.concat(p.filter(x => !attached.includes(x)));
    }
    function detach(p) {
        attached = attached.filter(x => x !== p);
    }
    function answer(rid, allow) {
        send_({ op: "answer", rid, allow });
    }
    function stop() {
        if (current)
            send_({ op: "stop", id: current });
    }
    function askArchive(id) {
        if (!id || !sessions.some(s => s.id === id))
            return;
        allOpen = false;
        confirmId = id;
    }
    function startRename() {
        if (current)
            renaming = true;
    }
    function commitRename(t) {
        renaming = false;
        if (current && t.trim() && t.trim() !== title)
            send_({ op: "rename", id: current, title: t.trim() });
        focusInput();
    }
    // An archived session is restored then opened
    function pickSession(id) {
        allOpen = false;
        if (allSessions.find(s => s.id === id)?.archived)
            send_({ op: "restore", id });
        openSession(id);
    }
    function openSettings() {
        if (testing) {
            ran = ran.concat(["xdg-open settings"]);
            return;
        }
        Link.spawn("xdg-open", configHome + "/filigrane/fili-ai.toml");
    }
    // Ctrl+V: files (text/uri-list) attached; an image is saved in ~/.local/state/filigrane/chat/images then attached
    function paste() {
        const out = Link.capture('t="$(wl-paste -l 2>/dev/null)"; if printf "%s\\n" "$t" | grep -qx text/uri-list; then wl-paste -t text/uri-list 2>/dev/null; elif m="$(printf "%s\\n" "$t" | grep -x -m1 image/png || printf "%s\\n" "$t" | grep -m1 "^image/[a-z]*$")" && [ -n "$m" ]; then d="${XDG_STATE_HOME:-$HOME/.local/state}/filigrane/chat/images"; mkdir -p "$d"; f="$d/image-$(date +%Y%m%d-%H%M%S).${m#image/}"; wl-paste -t "$m" > "$f" 2>/dev/null && [ -s "$f" ] && echo "file://$f"; fi');
        const urls = out.split("\n").map(l => l.trim()).filter(l => l.startsWith("file://"));
        attachUrls(urls);
        return urls.length > 0;
    }
    function confirmArchive(yes) {
        if (yes && confirmId)
            send_({ op: "archive", id: confirmId });
        confirmId = "";
    }
    function openSession(id) {
        followPending = false;
        if (id === current)
            return;
        current = id;
        live = "";
        markRead();
        send_({ op: "open", id });
        focusInput();
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
            allSessions = ev.sessions;
            sessions = ev.sessions.filter(s => !s.archived);
            sessionsFresh = true;
            const m = Object.assign({}, states);
            for (const s of sessions)
                m[s.id] = s.state;
            states = m;
            if (!sessions.some(s => s.id === current)) {
                current = pending ? current : (sessions[0]?.id ?? "");
                if (current && items[current] === undefined)
                    send_({ op: "open", id: current });
            }
            tryFollow();
            hereNow();
        } else if (ev.ev === "created") {
            const m = Object.assign({}, items);
            m[ev.id] = [];
            items = m;
            current = ev.id;
            live = "";
            if (pendingLink) {
                send_({ op: "link", id: ev.id, key: pendingLink });
                pendingLink = "";
            }
            if (pendingScope) {
                send_({ op: "scope", id: ev.id, on: true });
                pendingScope = false;
            }
            if (pending) {
                const t = pending;
                pending = "";
                const req = { op: "send", id: ev.id, text: t };
                if (ctxOn)
                    req.context = true;
                ctxOn = false;
                send_(req);
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
            if (ev.status === "pending" && i < 0 && !(open && ev.id === current))
                notifyAsk(ev.id, ev.rid, ev.tool, ev.summary);
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
            if (ev.state !== "idle")
                awaiting = false;
            if (ev.state === "idle" && ev.id === current)
                live = "";
            // Turn finished out of sight of the drawer: to read, and announced
            if (ev.state === "idle" && was !== "idle" && !(open && ev.id === current)) {
                const u = Object.assign({}, unread);
                u[ev.id] = true;
                unread = u;
                notify(ev.id, Link.tr("Lia has finished"), "normal");
            }
        } else if (ev.ev === "note") {
            append(ev.id, { kind: "note", text: ev.code === "interrupted" ? Link.tr("Interrupted") : ev.code, name: "" });
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
            if (Link.connected)
                chat.tries = 0;
            else if (chat.wantLink && chat.tries < 40)
                chat.connectNow();
        }
    }
}
