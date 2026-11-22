// Icon of an application by its name (the app_id of its window): the file in the icon themes of the system. The themes
// are searched in this order: the one named by GTK settings, hicolor, Adwaita; scalable first, then the largest raster.
use std::{env, fs, path::PathBuf};

fn data_dirs() -> Vec<PathBuf> {
    let home = env::var("HOME").unwrap_or_default();
    let mut dirs = vec![PathBuf::from(format!("{home}/.local/share"))];
    let xdg = env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    dirs.extend(xdg.split(':').filter(|d| !d.is_empty()).map(PathBuf::from));
    dirs
}

fn gtk_theme() -> Option<String> {
    let home = env::var("HOME").ok()?;
    let ini = fs::read_to_string(format!("{home}/.config/gtk-3.0/settings.ini")).ok()?;
    ini.lines().find_map(|l| l.strip_prefix("gtk-icon-theme-name=").map(|v| v.trim().to_string()))
}

// Sizes of a theme folder, best first: scalable, then from the largest raster
fn candidates(theme: &PathBuf) -> Vec<PathBuf> {
    let mut sizes: Vec<(u32, PathBuf)> = Vec::new();
    for ctx in ["apps", ""] {
        let Ok(rd) = fs::read_dir(theme) else { continue };
        for e in rd.flatten() {
            let name = e.file_name().to_string_lossy().into_owned();
            let n = if name == "scalable" { 100_000 } else { name.split('x').next().and_then(|n| n.parse().ok()).unwrap_or(0) };
            if n > 0 {
                sizes.push((n, if ctx.is_empty() { e.path() } else { e.path().join(ctx) }));
            }
        }
    }
    sizes.sort_by(|a, b| b.0.cmp(&a.0));
    sizes.into_iter().map(|s| s.1).collect()
}

pub fn find(name: &str) -> Option<String> {
    if name.is_empty() || name.contains('/') {
        return None;
    }
    let mut themes: Vec<String> = gtk_theme().into_iter().collect();
    themes.extend(["hicolor".to_string(), "Adwaita".to_string()]);
    let lower = name.to_lowercase();
    for base in data_dirs() {
        for theme in &themes {
            for dir in candidates(&base.join("icons").join(theme)) {
                for n in [name, lower.as_str()] {
                    for ext in ["svg", "png"] {
                        let p = dir.join(format!("{n}.{ext}"));
                        if p.is_file() {
                            return Some(p.to_string_lossy().into_owned());
                        }
                    }
                }
            }
        }
        for n in [name, lower.as_str()] {
            for ext in ["svg", "png"] {
                let p = base.join("pixmaps").join(format!("{n}.{ext}"));
                if p.is_file() {
                    return Some(p.to_string_lossy().into_owned());
                }
            }
        }
    }
    None
}
