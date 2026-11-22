// fili-ai-window: the window of Lia, the assistant of Filigrane (drawer on the right edge, layer-shell).
// The daemon (fili-ai-daemon) keeps the sessions; this window shows them and sends the messages.
mod ctl;
mod i18n;
mod icons;
mod logs;
mod link;
mod theme;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};

pub fn ui_socket() -> String {
    format!("{}/fili-ai/ui.sock", std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into()))
}

// The command of a command line: the arguments but the flags, on one line; "show" when there are none
pub fn command_of(args: &[String]) -> String {
    let words: Vec<&str> = args.iter().map(String::as_str).filter(|a| !a.starts_with("--")).collect();
    if words.is_empty() { "show".into() } else { words.join(" ").split_whitespace().collect::<Vec<_>>().join(" ") }
}

fn main() {
    // `fili-ai ctl ...`: the command line of the running window, before Qt
    if std::env::args().nth(1).is_some_and(|a| a == "ctl") {
        std::process::exit(ctl::run(&std::env::args().skip(2).collect::<Vec<_>>()));
    }
    if std::env::args().nth(1).is_some_and(|a| a == "-V" || a == "--version") {
        println!("fili-ai-window {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    // One window at a time: a running one takes the command (`toggle`, `here TEXT`...) and this process ends at once,
    // before Qt is loaded (Mod+Y must be quick)
    let args: Vec<String> = std::env::args().skip(1).collect();
    if let Ok(mut s) = std::os::unix::net::UnixStream::connect(ui_socket()) {
        use std::io::Write;
        if writeln!(s, "{}", command_of(&args)).is_ok() {
            return;
        }
    }
    // The drawer is a layer-shell surface (package layer-shell-qt), chosen before Qt starts. `--window`: a normal window
    // (tests, compositors without layer-shell)
    if !std::env::args().any(|a| a == "--window") && std::env::var_os("QT_WAYLAND_SHELL_INTEGRATION").is_none() {
        // SAFETY: single-threaded at this point, before Qt creates any thread
        unsafe { std::env::set_var("QT_WAYLAND_SHELL_INTEGRATION", "layer-shell") };
    }
    // The log of the window (Debug panel): ~/.local/state/filigrane/logs/fili-ai.log; panics and QML errors become incidents
    let incidents = !std::fs::read_to_string(theme::path()).unwrap_or_default().lines().any(|l| l.replace(' ', "") == "incidents=\"off\"");
    logs::init("fili-ai", "filigrane-os/fili-ai", option_env!("FILI_AI_GIT").unwrap_or(env!("CARGO_PKG_VERSION")), incidents);
    logs::capture_qt();
    let mut app = QGuiApplication::new();
    QGuiApplication::set_desktop_file_name(&QString::from("fili-ai"));
    let mut engine = QQmlApplicationEngine::new();
    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/Fili/Ai/qml/Main.qml"));
    }
    if let Some(app) = app.as_mut() {
        std::process::exit(app.exec());
    }
}

#[cfg(test)]
mod tests {
    use super::command_of;

    #[test]
    fn a_command_is_one_line_without_flags() {
        let v = |a: &[&str]| command_of(&a.iter().map(|s| s.to_string()).collect::<Vec<_>>());
        assert_eq!(v(&[]), "show");
        assert_eq!(v(&["--window"]), "show");
        assert_eq!(v(&["here", "two  words\nand more"]), "here two words and more");
    }
}
