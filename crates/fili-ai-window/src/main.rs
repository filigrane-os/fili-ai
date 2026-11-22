// fili-ai-window: the window of Lia, the assistant of Filigrane (drawer on the right edge, layer-shell).
// The daemon (fili-ai-daemon) keeps the sessions; this window shows them and sends the messages.
mod icons;
mod link;
mod theme;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};

fn main() {
    if std::env::args().nth(1).is_some_and(|a| a == "-V" || a == "--version") {
        println!("fili-ai-window {}", env!("CARGO_PKG_VERSION"));
        return;
    }
    // The drawer is a layer-shell surface (package layer-shell-qt), chosen before Qt starts. `--window`: a normal window
    // (tests, compositors without layer-shell)
    if !std::env::args().any(|a| a == "--window") && std::env::var_os("QT_WAYLAND_SHELL_INTEGRATION").is_none() {
        // SAFETY: single-threaded at this point, before Qt creates any thread
        unsafe { std::env::set_var("QT_WAYLAND_SHELL_INTEGRATION", "layer-shell") };
    }
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
