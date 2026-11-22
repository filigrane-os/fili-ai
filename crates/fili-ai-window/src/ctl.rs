// `fili-ai ctl [--pid PID] VERB`: the command line of the running window (docs/api.md, "Control"). The window is a single
// instance reached through its socket, so --pid is accepted and not needed.
use std::io::Write;

// The names `action NAME` accepts; shell/ctl/fili-ai.json lists them with their labels (fili-api-lint --write)
pub const ACTIONS: &[&str] = &[
    "about", "toggle", "show", "close", "new", "new-here", "sessions", "rename", "unlink", "archive", "stop", "allow", "deny",
    "drop-context", "float", "dock", "width-narrow", "width-medium", "width-wide", "settings",
];

const USAGE: &str = "usage: fili-ai ctl [--pid PID] action NAME [ARG...] | state | actions";

pub fn run(args: &[String]) -> i32 {
    // --pid PID is the contract of every application; one window at a time here
    let mut rest: Vec<&str> = Vec::new();
    let mut it = args.iter().map(String::as_str);
    while let Some(a) = it.next() {
        if a == "--pid" {
            it.next();
        } else {
            rest.push(a);
        }
    }
    match rest.as_slice() {
        ["action", name, more @ ..] => {
            if !ACTIONS.contains(name) && !matches!(*name, "open" | "ask" | "here" | "answer") {
                eprintln!("fili-ai ctl: unknown action {name}\n{USAGE}");
                return 1;
            }
            let line = std::iter::once(*name).chain(more.iter().copied()).collect::<Vec<_>>().join(" ");
            match std::os::unix::net::UnixStream::connect(crate::ui_socket()) {
                Ok(mut s) => {
                    let _ = writeln!(s, "{}", line.split_whitespace().collect::<Vec<_>>().join(" "));
                    0
                }
                Err(_) => {
                    // No window: this starts one with the command
                    let _ = std::process::Command::new(std::env::current_exe().unwrap_or_else(|_| "fili-ai-window".into()))
                        .args(line.split_whitespace())
                        .stdin(std::process::Stdio::null())
                        .stdout(std::process::Stdio::null())
                        .stderr(std::process::Stdio::null())
                        .spawn();
                    0
                }
            }
        }
        ["state"] => {
            let dir = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
            // No window: closed and idle
            let text = std::fs::read_to_string(format!("{dir}/fili/ai/ui.json"))
                .unwrap_or_else(|_| "{\"v\":1,\"open\":false,\"focused\":false,\"attention\":\"\",\"busy\":false}".into());
            println!("{}", text.trim());
            0
        }
        ["actions"] => {
            println!("{}", ACTIONS.join("\n"));
            0
        }
        _ => {
            eprintln!("{USAGE}");
            1
        }
    }
}
