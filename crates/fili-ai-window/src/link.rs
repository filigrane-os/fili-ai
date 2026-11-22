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
        type Link = super::LinkRust;

        #[qsignal]
        #[cxx_name = "connectedChanged"]
        fn connected_changed(self: Pin<&mut Link>);
        // One line received from the daemon (JSON text)
        #[qsignal]
        fn line(self: Pin<&mut Link>, text: &QString);

        // Connects to the daemon socket (path given by `socketPath`); false when nobody listens
        #[qinvokable]
        #[cxx_name = "open"]
        fn open(self: Pin<&mut Link>) -> bool;
        #[qinvokable]
        fn write(self: Pin<&mut Link>, text: &QString);
        #[qinvokable]
        #[cxx_name = "socketPath"]
        fn socket_path(self: &Link) -> QString;
        #[qinvokable]
        fn env(self: &Link, name: &QString) -> QString;
        // Starts a program without waiting for it (the daemon, `fili-ai-session`, notifications)
        #[qinvokable]
        fn spawn(self: &Link, program: &QString, args: &QString);
    }

    impl cxx_qt::Threading for Link {}
}

use cxx_qt_lib::QString;

#[derive(Default)]
pub struct LinkRust {
    connected: bool,
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

    fn env(&self, name: &QString) -> QString {
        QString::from(&std::env::var(name.to_string()).unwrap_or_default())
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
