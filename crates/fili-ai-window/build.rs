// QML of the drawer compiled into the binary (module Fili.Ai, qrc:/qt/qml/Fili/Ai/qml/), Rust objects of src/link.rs
use cxx_qt_build::{CxxQtBuilder, QmlFile, QmlModule};

fn main() {
    // Version of the About card: tag or commit of the repository (absent outside a repository)
    if let Ok(o) = std::process::Command::new("git").args(["describe", "--tags", "--always", "--dirty"]).output() {
        if o.status.success() {
            println!("cargo:rustc-env=FILI_AI_GIT={}", String::from_utf8_lossy(&o.stdout).trim());
        }
    }
    CxxQtBuilder::new_qml_module(
        QmlModule::new("Fili.Ai")
            .qml_files(["qml/Main.qml", "qml/Drawer.qml", "qml/Bubble.qml", "qml/IconButton.qml", "qml/Ask.qml", "qml/About.qml"])
            .qml_file(QmlFile::from("qml/Theme.qml").singleton(true))
            .qml_file(QmlFile::from("qml/Chat.qml").singleton(true))
            .depend("QtQuick")
            .depend("QtQuick.Controls")
            .depend("QtQuick.Layouts"),
    )
    // Fonts of the interface travel with the binary: the application looks the same on any distribution
    .qrc_resources(["fonts/Jost-Variable.ttf", "fonts/JetBrainsMono-Variable.ttf", "fonts/FiliIcons.ttf"])
    .qt_module("Quick")
    .files(["src/link.rs"])
    .build();
}
