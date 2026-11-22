// The line protocol of the daemon (crates/fili-ai-daemon): JSON objects, one per line, over the Unix socket
// $XDG_RUNTIME_DIR/fili-ai/sock. The conversation logic is in qml/Chat.qml; this object only moves lines.
use std::{
    io::{BufRead, BufReader, Write},
    os::unix::net::UnixStream,
    pin::Pin,
};

use cxx_qt::{CxxQtType, Threading};

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qml_singleton]
        #[qproperty(bool, connected, READ, WRITE, NOTIFY = connected_changed)]
        // Look of the window: light mode and accent of `fili-theme`; settingsRev counts the changes of the settings files
        #[qproperty(bool, light, READ, WRITE, NOTIFY = theme_changed)]
        #[qproperty(QString, accent, READ, WRITE, NOTIFY = theme_changed)]
        #[qproperty(i32, settings_rev, cxx_name = "settingsRev", READ, WRITE, NOTIFY = theme_changed)]
        type Link = super::LinkRust;

        #[qsignal]
        #[cxx_name = "themeChanged"]
        fn theme_changed(self: Pin<&mut Link>);
        // Merged theme as JSON (defaults, theme.toml, fili-ai.toml): see theme.rs
        #[qinvokable]
        #[cxx_name = "themeJson"]
        fn theme_json(self: &Link) -> QString;
        // Starts following the settings and `fili-theme` files (polled once a second)
        #[qinvokable]
        #[cxx_name = "watchTheme"]
        fn watch_theme(self: Pin<&mut Link>);

        #[qsignal]
        #[cxx_name = "connectedChanged"]
        fn connected_changed(self: Pin<&mut Link>);
        // One line received from the daemon (JSON text)
        #[qsignal]
        fn line(self: Pin<&mut Link>, text: &QString);
        // A command of the command line or of the shell (`fili-ai toggle`, `here TEXT`, `answer RID:yes`...): one line
        #[qsignal]
        fn command(self: Pin<&mut Link>, text: &QString);
        // Listens on $XDG_RUNTIME_DIR/fili-ai/ui.sock: the next `fili-ai-window VERB` reaches this window
        #[qinvokable]
        #[cxx_name = "serveCommands"]
        fn serve_commands(self: Pin<&mut Link>);
        // The command given on the command line of this process ("show" by default)
        #[qinvokable]
        #[cxx_name = "initialCommand"]
        fn initial_command(self: &Link) -> QString;

        // Connects to the daemon socket (path given by `socketPath`); false when nobody listens
        #[qinvokable]
        #[cxx_name = "open"]
        fn open(self: Pin<&mut Link>) -> bool;
        #[qinvokable]
        fn write(self: Pin<&mut Link>, text: &QString);
        #[qinvokable]
        #[cxx_name = "socketPath"]
        fn socket_path(self: &Link) -> QString;
        // Path of the icon of an application (icon theme, then hicolor, then pixmaps), "" when there is none
        #[qinvokable]
        #[cxx_name = "iconPath"]
        fn icon_path(self: &Link, name: &QString) -> QString;
        // Small text files of the user (view state, settings): whole content, "" when absent; write replaces it
        #[qinvokable]
        #[cxx_name = "readText"]
        fn read_text(self: &Link, path: &QString) -> QString;
        #[qinvokable]
        #[cxx_name = "writeText"]
        fn write_text(self: &Link, path: &QString, text: &QString);
        #[qinvokable]
        fn version(self: &Link) -> QString;
        #[qinvokable]
        fn env(self: &Link, name: &QString) -> QString;
        // Starts a program without waiting for it (the daemon, `fili-ai-session`, notifications)
        // Runs `sh -c SCRIPT` and gives its output (short commands only: it waits)
        #[qinvokable]
        fn capture(self: &Link, script: &QString) -> QString;
        #[qinvokable]
        fn spawn(self: &Link, program: &QString, args: &QString);
    }

    impl cxx_qt::Threading for Link {}
}

use cxx_qt_lib::QString;


#[derive(Default)]
pub struct LinkRust {
    connected: bool,
    light: bool,
    accent: QString,
    settings_rev: i32,
    writer: Option<UnixStream>,
}

pub fn socket() -> String {
    format!("{}/fili-ai/sock", std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into()))
}

impl qobject::Link {
    fn open(mut self: Pin<&mut Self>) -> bool {
        if self.rust().writer.is_some() {
            return true;
        }
        let Ok(stream) = UnixStream::connect(socket()) else { return false };
        let Ok(reader) = stream.try_clone() else { return false };
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            for line in BufReader::new(reader).lines() {
                let Ok(line) = line else { break };
                if qt.queue(move |mut link| link.as_mut().line(&QString::from(&line))).is_err() {
                    return;
                }
            }
            // Daemon gone: the state goes back to "not connected"
            let _ = qt.queue(|mut link| {
                link.as_mut().rust_mut().writer = None;
                link.as_mut().set_connected(false);
            });
        });
        self.as_mut().rust_mut().writer = Some(stream);
        self.as_mut().set_connected(true);
        true
    }

    fn write(mut self: Pin<&mut Self>, text: &QString) {
        let mut line = text.to_string();
        line.push('\n');
        let failed = self.as_mut().rust_mut().writer.as_mut().is_none_or(|w| w.write_all(line.as_bytes()).is_err());
        if failed && self.rust().writer.is_some() {
            self.as_mut().rust_mut().writer = None;
            self.as_mut().set_connected(false);
        }
    }

    fn socket_path(&self) -> QString {
        QString::from(&socket())
    }

    fn theme_json(&self) -> QString {
        QString::from(&crate::theme::theme_json())
    }

    fn watch_theme(mut self: Pin<&mut Self>) {
        let (light, accent) = (crate::theme::read_light(), crate::theme::read_accent());
        self.as_mut().set_light(light);
        self.as_mut().set_accent(QString::from(&accent));
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            let mut last = crate::theme::stamp();
            loop {
                std::thread::sleep(std::time::Duration::from_secs(1));
                let now = crate::theme::stamp();
                if now == last {
                    continue;
                }
                last = now;
                let (light, accent) = (crate::theme::read_light(), crate::theme::read_accent());
                if qt
                    .queue(move |mut l| {
                        let rev = *l.settings_rev() + 1;
                        l.as_mut().set_light(light);
                        l.as_mut().set_accent(QString::from(&accent));
                        l.as_mut().set_settings_rev(rev);
                    })
                    .is_err()
                {
                    return;
                }
            }
        });
    }

    fn initial_command(&self) -> QString {
        QString::from(&crate::command_of(&std::env::args().skip(1).collect::<Vec<_>>()))
    }

    fn serve_commands(self: Pin<&mut Self>) {
        let path = crate::ui_socket();
        if let Some(dir) = std::path::Path::new(&path).parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        let _ = std::fs::remove_file(&path);
        let Ok(listener) = std::os::unix::net::UnixListener::bind(&path) else { return };
        let qt = self.qt_thread();
        std::thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                for line in BufReader::new(stream).lines().map_while(Result::ok) {
                    if qt.queue(move |mut l| l.as_mut().command(&QString::from(&line))).is_err() {
                        return;
                    }
                }
            }
        });
    }

    fn icon_path(&self, name: &QString) -> QString {
        QString::from(&crate::icons::find(&name.to_string()).unwrap_or_default())
    }

    fn read_text(&self, path: &QString) -> QString {
        QString::from(&std::fs::read_to_string(path.to_string()).unwrap_or_default())
    }

    fn write_text(&self, path: &QString, text: &QString) {
        let path = std::path::PathBuf::from(path.to_string());
        if let Some(dir) = path.parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        // Atomic: a reader (the shell, inotify) never sees half a file
        let tmp = path.with_extension("tmp");
        if std::fs::write(&tmp, text.to_string()).is_ok() {
            let _ = std::fs::rename(&tmp, &path);
        }
    }

    fn version(&self) -> QString {
        QString::from(option_env!("FILI_AI_GIT").unwrap_or(env!("CARGO_PKG_VERSION")))
    }

    fn env(&self, name: &QString) -> QString {
        QString::from(&std::env::var(name.to_string()).unwrap_or_default())
    }

    fn capture(&self, script: &QString) -> QString {
        let out = std::process::Command::new("sh").arg("-c").arg(script.to_string()).stdin(std::process::Stdio::null()).output();
        QString::from(&out.map(|o| String::from_utf8_lossy(&o.stdout).into_owned()).unwrap_or_default())
    }

    fn spawn(&self, program: &QString, args: &QString) {
        let args = args.to_string();
        let _ = std::process::Command::new(program.to_string())
            .args(args.split('\u{1f}').filter(|a| !a.is_empty()))
            .stdin(std::process::Stdio::null())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn();
    }
}
