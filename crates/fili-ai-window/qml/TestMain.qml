// Tests of the conversation logic (Chat.qml), run by `fili-ai-window --test` (make check): the events of the daemon are fed
// to Chat.receive and what Chat would send to the daemon, run or publish is read from its lists. TAP lines on the output.
import QtQuick
import Fili.Ai

QtObject {
    id: t
    property int count: 0
    property int failures: 0
    function ok(cond, name, detail) {
        count++;
        if (!cond)
            failures++;
        console.log((cond ? "ok " : "not ok ") + count + " - " + name + (cond || detail === undefined ? "" : " # " + detail));
    }
    function sess(id, extra) {
        return Object.assign({ id: id, title: "S" + id, state: "idle", archived: false, link: "", icon: 0 }, extra ?? {});
    }
    function reset() {
        Chat.sessions = [];
        Chat.allSessions = [];
        Chat.current = "";
        Chat.items = ({});
        Chat.states = ({});
        Chat.unread = ({});
        Chat.queued = ({});
        Chat.live = "";
        Chat.pending = "";
        Chat.pendingLink = "";
        Chat.pendingScope = false;
        Chat.pendingAsk = "";
        Chat.hereWant = false;
        Chat.hereText = "";
        Chat.open = false;
        Chat.ctx = null;
        Chat.ctxOn = false;
        Chat.ctxReady = false;
        Chat.sessionsFresh = false;
        Chat.followPending = false;
        Chat.follow = "app";
        Chat.attached = [];
        Chat.confirmId = "";
        Chat.awaiting = false;
        Chat.sent = [];
        Chat.ran = [];
        Chat.published = [];
        Chat.testLinked = true;
    }
    function ops() {
        return Chat.sent.map(o => o.op).join(",");
    }

    Component.onCompleted: {
        Chat.testing = true;

        // ───── sessions ─────
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a"), t.sess("b", { archived: true }), t.sess("c")] });
        ok(Chat.sessions.length === 2 && Chat.allSessions.length === 3, "sessions: archived ones are kept out of the rail, in the full list");
        ok(Chat.current === "a" && ops() === "open", "sessions: the first one is shown and its history asked", ops());
        const many = [];
        for (let i = 0; i < 25; i++)
            many.push(t.sess("m" + i));
        reset();
        Chat.receive({ ev: "sessions", sessions: many });
        ok(Chat.tabSessions.length === 20, "sessions: the rail shows 20");
        Chat.current = "m24";
        ok(Chat.tabSessions.length === 20 && Chat.tabSessions[19].id === "m24", "sessions: the current one replaces the last when it is older");

        // ───── the log ─────
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a")] });
        Chat.receive({ ev: "history", id: "a", items: [{ ev: "msg", role: "user", text: "hi" }, { ev: "tool", summary: "ls", name: "Bash" }] });
        ok(Chat.log.length === 2 && Chat.log[0].kind === "user" && Chat.log[1].kind === "tool", "history: messages and tool calls");
        Chat.receive({ ev: "delta", id: "a", text: "Hel" });
        Chat.receive({ ev: "delta", id: "a", text: "lo" });
        ok(Chat.live === "Hello", "delta: the answer being written");
        Chat.receive({ ev: "msg", id: "a", role: "assistant", text: "Hello!" });
        ok(Chat.live === "" && Chat.log.length === 3 && Chat.log[2].text === "Hello!", "msg: the written answer replaces the live text");
        Chat.receive({ ev: "delta", id: "zzz", text: "other" });
        ok(Chat.live === "", "delta: another session is not shown");
        Chat.receive({ ev: "note", id: "a", code: "interrupted" });
        ok(Chat.log[Chat.log.length - 1].kind === "note", "note: interrupted");

        // ───── permissions ─────
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a")] });
        Chat.receive({ ev: "history", id: "a", items: [] });
        Chat.receive({ ev: "ask", id: "a", rid: "r1", tool: "Bash", summary: "sudo sv restart iwd", status: "pending" });
        ok(Chat.waiting && Chat.log[0].kind === "ask", "ask: the permission is in the log and the session waits");
        ok(Chat.ran.length === 1 && Chat.ran[0].indexOf("r1") >= 0 && Chat.ran[0].indexOf("sudo sv restart iwd") >= 0, "ask: out of sight, a notification asks", JSON.stringify(Chat.ran));
        Chat.ran = [];
        Chat.receive({ ev: "ask", id: "a", rid: "r1", tool: "Bash", summary: "sudo sv restart iwd", status: "allowed" });
        ok(Chat.ran.length === 1 && Chat.ran[0].indexOf("Lia needs you") >= 0, "ask: once settled, the notification bubble is closed", JSON.stringify(Chat.ran));
        ok(Chat.log.length === 1 && Chat.log[0].status === "allowed" && !Chat.waiting, "ask: the same request is updated when settled, not added");
        Chat.open = true;
        Chat.ran = [];
        Chat.receive({ ev: "ask", id: "a", rid: "r2", tool: "Edit", summary: "x", status: "pending" });
        ok(Chat.ran.length === 0, "ask: no notification while the drawer shows that session");
        Chat.sent = [];
        Chat.answerFirst(true);
        ok(Chat.sent.length === 1 && Chat.sent[0].op === "answer" && Chat.sent[0].rid === "r2" && Chat.sent[0].allow === true, "answerFirst: allows the first pending permission", JSON.stringify(Chat.sent));
        Chat.sent = [];
        Chat.act("answer r9:no");
        ok(Chat.sent[0]?.rid === "r9" && Chat.sent[0]?.allow === false, "act answer RID:no: from the notification", JSON.stringify(Chat.sent));

        // ───── states, attention, unread ─────
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a"), t.sess("b")] });
        Chat.receive({ ev: "state", id: "a", state: "working" });
        ok(Chat.busy && Chat.working && Chat.attention === "", "state: working");
        Chat.receive({ ev: "state", id: "b", state: "waiting" });
        ok(Chat.attention === "waiting", "attention: a session waits for an answer");
        Chat.receive({ ev: "state", id: "b", state: "idle" });
        Chat.ran = [];
        Chat.receive({ ev: "state", id: "a", state: "idle" });
        ok(Chat.attention === "done" && Chat.unread["a"] === true && !Chat.busy, "attention: a finished turn out of sight is unread");
        Chat.receive({ ev: "state", id: "b", state: "working" });
        Chat.ran = [];
        Chat.receive({ ev: "state", id: "b", state: "idle" });
        ok(Chat.ran.length === 1 && Chat.ran[0].indexOf("Lia has finished") >= 0, "state: a finished turn out of sight is announced", JSON.stringify(Chat.ran));
        Chat.openSession("b");
        ok(Chat.current === "b" && Chat.sent[Chat.sent.length - 1].op === "open", "openSession: shows it and asks its history");
        Chat.openSession("a");
        Chat.show();
        ok(Chat.unread["a"] === undefined, "show: opening the drawer on a session marks it read");
        Chat.ran = [];
        Chat.receive({ ev: "state", id: "a", state: "working" });
        Chat.receive({ ev: "state", id: "a", state: "idle" });
        ok(Chat.ran.length === 0 && Chat.unread["a"] === undefined, "state: a turn finished in the shown session is neither unread nor announced");

        // ───── sending ─────
        reset();
        Chat.send("   ");
        ok(Chat.sent.length === 0, "send: an empty message is not sent");
        Chat.send("hello");
        ok(ops() === "new" && Chat.pending === "hello", "send: without a session, one is created first", ops());
        Chat.receive({ ev: "created", id: "n1" });
        ok(Chat.current === "n1" && ops() === "new,send" && Chat.sent[1].text === "hello" && Chat.pending === "", "created: the waiting message goes to the new session", ops());
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a")] });
        Chat.sent = [];
        Chat.send("again");
        ok(ops() === "send" && Chat.sent[0].id === "a" && Chat.sent[0].context === undefined, "send: to the current session, no context");
        // with the context of an application
        Chat.ctx = { window: { app_id: "fili-file", title: "Docs" } };
        Chat.ctxOn = true;
        Chat.sent = [];
        Chat.send("here");
        ok(ops() === "link,send" && Chat.sent[0].key === "fili-file" && Chat.sent[1].context === true && !Chat.ctxOn, "send: the first message with an application links the session and carries the context", ops());
        Chat.ctxOn = true;
        Chat.receive({ ev: "sessions", sessions: [t.sess("a", { link: "fili-file" })] });
        Chat.sent = [];
        Chat.send("more");
        ok(ops() === "send", "send: an already linked session is not linked again", ops());
        // attachments
        Chat.ctxOn = false;
        Chat.attachUrls(["file:///tmp/a%20b.txt", "http://x/y", "file:///tmp/c.png"]);
        ok(Chat.attached.length === 2 && Chat.attached[0] === "/tmp/a b.txt", "attachUrls: only files, decoded", JSON.stringify(Chat.attached));
        Chat.detach("/tmp/c.png");
        Chat.sent = [];
        Chat.send("");
        ok(Chat.sent[0]?.text.indexOf("/tmp/a b.txt") >= 0 && Chat.attached.length === 0, "send: attached files are listed in the message, then cleared", JSON.stringify(Chat.sent));

        // ───── link keys and follow ─────
        reset();
        const c = { window: { app_id: "fili-file", title: "Docs" } };
        ok(Chat.linkKey(c) === "fili-file" && Chat.linkKey(null) === "", "linkKey: the app_id, nothing without an application");
        Chat.follow = "window";
        ok(Chat.linkKey(c) === "fili-file\nDocs", "linkKey: window mode adds the title");
        Chat.follow = "off";
        ok(Chat.linkKey(c) === "" && Chat.linkKey(c, true) === "fili-file", "linkKey: off, unless forced");
        Chat.follow = "app";
        Chat.receive({ ev: "sessions", sessions: [t.sess("a"), t.sess("b", { link: "fili-file" })] });
        Chat.current = "a";
        Chat.ctx = c;
        Chat.ctxReady = true;
        Chat.followPending = true;
        Chat.tryFollow();
        ok(Chat.current === "b", "follow: the session linked to the application is resumed");
        Chat.current = "a";
        Chat.followPending = true;
        Chat.states = { a: "working" };
        Chat.tryFollow();
        ok(Chat.current === "a", "follow: a turn in progress stays in sight");

        // ───── commands ─────
        reset();
        Chat.act("toggle");
        ok(Chat.open, "act toggle: opens");
        Chat.act("toggle");
        ok(!Chat.open, "act toggle: hides");
        Chat.act("show");
        Chat.act("close");
        ok(!Chat.open, "act show, close");
        Chat.receive({ ev: "sessions", sessions: [t.sess("a"), t.sess("b")] });
        Chat.act("open b");
        ok(Chat.open && Chat.current === "b", "act open ID: shows the drawer on that session");
        Chat.sent = [];
        Chat.act("new");
        ok(ops() === "new", "act new");
        Chat.act("stop");
        ok(ops() === "new,stop", "act stop");
        Chat.act("float");
        ok(Chat.mode === "float", "act float");
        Chat.act("dock");
        Chat.act("width-wide");
        ok(Chat.mode === "dock" && Chat.viewWidth === 560, "act dock, width-wide");
        ok(Chat.clampWidth(10) === 300 && Chat.clampWidth(5000) === 900 && Chat.clampWidth(500) === 500, "clampWidth: 300 to 900");
        Chat.sent = [];
        Chat.act("unlink");
        ok(Chat.sent[0]?.op === "link" && Chat.sent[0].key === "", "act unlink");
        Chat.act("archive");
        ok(Chat.confirmId === "b", "act archive: asks for a confirmation first");
        Chat.confirmArchive(false);
        ok(Chat.confirmId === "" && Chat.sent[Chat.sent.length - 1].op !== "archive", "confirmArchive(false): nothing archived");
        Chat.askArchive("b");
        Chat.confirmArchive(true);
        ok(Chat.sent[Chat.sent.length - 1].op === "archive" && Chat.sent[Chat.sent.length - 1].id === "b", "confirmArchive(true): archives");
        Chat.act("settings");
        ok(Chat.ran[Chat.ran.length - 1] === "xdg-open settings", "act settings");
        // commands that go to a window of the application
        let fields = 0, abouts = 0;
        Chat.fieldRequested.connect(() => fields++);
        Chat.aboutRequested.connect(() => abouts++);
        Chat.act("here");
        Chat.act("about");
        ok(fields === 1 && abouts === 1, "act here (no text): the floating field; act about: the card");

        // ───── ask and here ─────
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a")] });
        Chat.ctx = c;
        Chat.ctxReady = true;
        Chat.sent = [];
        Chat.here("why?");
        ok(Chat.open && ops() === "new" && Chat.pendingLink === "fili-file" && Chat.pendingScope && Chat.pending === "why?", "here TEXT: a scoped session linked to the application is created", ops() + " " + Chat.pendingLink);
        Chat.receive({ ev: "created", id: "n2" });
        ok(ops() === "new,link,scope,send" && Chat.sent[3].text === "why?", "created: link, scope, then the question", ops());
        reset();
        Chat.ctx = c;
        Chat.sent = [];
        Chat.askHere("quiet", false);
        ok(!Chat.open && Chat.awaiting && ops() === "new" && Chat.pendingLink === "fili-file", "askHere: the drawer stays closed, the link is kept until the agent works, a scoped session is created", ops());
        reset();
        Chat.sent = [];
        Chat.askHere("no application", false);
        ok(Chat.open && ops() === "new", "askHere: without an application noted, an ordinary drawer opens", ops());
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a")] });
        Chat.sent = [];
        Chat.ctxReady = true;
        Chat.pendingAsk = "boom";
        Chat.askNow();
        ok(ops() === "new" && Chat.pending === "boom", "ask: a failed command of an application opens a new session");

        // ───── state for the shell ─────
        reset();
        Chat.receive({ ev: "sessions", sessions: [t.sess("a")] });
        Chat.receive({ ev: "state", id: "a", state: "waiting" });
        const ui = JSON.parse(Chat.uiJson());
        ok(ui.v === 1 && ui.open === false && ui.attention === "waiting" && ui.busy === true && ui.focused === false, "ui.json: version, open, focused, attention, busy", Chat.uiJson());

        // ───── agent ─────
        Chat.receive({ ev: "agent", ok: false });
        ok(Chat.agentOk === false, "agent: not installed");
        console.log("# end: " + failures + " failure(s) out of " + count);
        Qt.exit(failures === 0 ? 0 : 1);
    }
}
