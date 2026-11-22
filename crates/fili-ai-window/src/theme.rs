// Theme of the window: the defaults of theme.toml (embedded), the shared ~/.config/filigrane/theme.toml and the own
// ~/.config/filigrane/fili-ai.toml, key by key (sections [theme], [theme.dark], [theme.light], [theme.accents]); light
// mode and accent follow `fili-theme` (state files). Same layers and lookup as Casier (fili-file), whose copy this is.
use std::{collections::BTreeMap, env, path::PathBuf};

pub fn path() -> PathBuf {
    let home = env::var("HOME").unwrap_or_default();
    let dir = env::var("XDG_CONFIG_HOME").unwrap_or_else(|_| format!("{home}/.config"));
    PathBuf::from(dir).join("filigrane/fili-ai.toml")
}

// Cuts at the first "#" outside quotes (colors such as "#1c222b" contain one)
fn strip_comment(line: &str) -> &str {
    let mut quoted = false;
    for (i, ch) in line.char_indices() {
        match ch {
            '"' => quoted = !quoted,
            '#' if !quoted => return &line[..i],
            _ => {}
        }
    }
    line
}

// ---- Theme -------------------------------------------------------------------------------------------------
// The defaults are in theme.toml (embedded); ~/.config/filigrane/fili-file.toml overrides them key by key.
// Lookup order of a key: the user's [theme.<mode>], their [theme], the defaults' [theme.<mode>], their [theme].

#[derive(Clone, Debug, PartialEq)]
enum Val {
    Str(String),
    List(Vec<String>),
}

type Sections = BTreeMap<String, BTreeMap<String, Val>>;

#[derive(Clone, Copy, PartialEq)]
enum Kind {
    Color,
    Int,
    Str,
}

// (TOML key, type): all of them apply in [theme] and in each mode
const KEYS: &[(&str, Kind)] = &[
    ("background", Kind::Color),
    ("background_deep", Kind::Color),
    ("surface", Kind::Color),
    ("surface_hover", Kind::Color),
    ("surface_active", Kind::Color),
    ("border", Kind::Color),
    ("muted", Kind::Color),
    ("text_secondary", Kind::Color),
    ("text", Kind::Color),
    ("warning", Kind::Color),
    ("danger", Kind::Color),
    ("success", Kind::Color),
    ("accent", Kind::Color),        // optional: without a value, the accent follows fili-theme
    ("accent_bright", Kind::Color), // optional
    ("font", Kind::Str),
    ("mono", Kind::Str),
    ("icons", Kind::Str),
    ("size", Kind::Int),
    ("size_list", Kind::Int),
    ("size_small", Kind::Int),
    ("size_label", Kind::Int),
    ("size_title", Kind::Int),
    ("weight_accent", Kind::Int),
    ("radius_mark", Kind::Int),
    ("radius_control", Kind::Int),
    ("radius_window", Kind::Int),
    ("border_width", Kind::Int),
    ("space_1", Kind::Int),
    ("space_2", Kind::Int),
    ("space_3", Kind::Int),
    ("space_4", Kind::Int),
    ("space_5", Kind::Int),
    ("space_6", Kind::Int),
    ("row_height", Kind::Int),
    ("side_row_height", Kind::Int),
    ("icon_size", Kind::Int),
    ("margin", Kind::Int),
    ("toolbar_height", Kind::Int),
    ("status_height", Kind::Int),
    ("sidebar_width", Kind::Int),
    ("tab_bar_height", Kind::Int),
    ("tab_height", Kind::Int),
];

const DEFAULT_THEME: &str = include_str!("../theme.toml");

fn parse_value(v: &str) -> Val {
    let v = v.trim();
    if let Some(inner) = v.strip_prefix('[').and_then(|r| r.strip_suffix(']')) {
        Val::List(inner.split(',').map(|x| x.trim().trim_matches('"').trim().to_string()).filter(|x| !x.is_empty()).collect())
    } else {
        Val::Str(v.trim_matches('"').trim().to_string())
    }
}

fn parse_sections(text: &str) -> Sections {
    let mut out = Sections::new();
    let mut section = String::new();
    for line in text.lines() {
        let line = strip_comment(line).trim();
        if let Some(name) = line.strip_prefix('[').and_then(|r| r.strip_suffix(']')) {
            section = name.trim().to_string();
        } else if let Some((k, v)) = line.split_once('=') {
            out.entry(section.clone()).or_default().insert(k.trim().to_string(), parse_value(v));
        }
    }
    out
}

fn valid_color(s: &str) -> bool {
    s.strip_prefix('#').is_some_and(|h| matches!(h.len(), 3 | 6 | 8) && h.chars().all(|c| c.is_ascii_hexdigit()))
}

fn valid(kind: Kind, s: &str) -> bool {
    match kind {
        Kind::Color => valid_color(s),
        Kind::Int => s.parse::<u32>().is_ok(),
        Kind::Str => !s.is_empty(),
    }
}

fn json_str(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            c if (c as u32) < 0x20 => o.push(' '),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

// Accent tones: the user's (4 valid colors) replace the defaults', by name
fn accents_from(layers: &[&Sections]) -> BTreeMap<String, Vec<String>> {
    let mut accents = BTreeMap::new();
    for sections in layers {
        for (name, v) in sections.get("theme.accents").into_iter().flatten() {
            if let Val::List(l) = v {
                if l.len() == 4 && l.iter().all(|c| valid_color(c)) {
                    accents.insert(name.clone(), l.clone());
                }
            }
        }
    }
    accents
}

// Tone [dark, dark bright, light, light bright] of an accent name (read once), `default` if the name is unknown
pub fn accent_tone(name: &str) -> Vec<String> {
    static TONES: std::sync::OnceLock<BTreeMap<String, Vec<String>>> = std::sync::OnceLock::new();
    let tones = TONES.get_or_init(|| {
        let read = |p: PathBuf| parse_sections(&std::fs::read_to_string(p).unwrap_or_default());
        accents_from(&[&parse_sections(DEFAULT_THEME), &read(global_path()), &read(path())])
    });
    tones.get(name).or_else(|| tones.get("default")).cloned().unwrap_or_default()
}

// Merged theme as JSON: {"dark": {key: value}, "light": {...}, "accents": {name: [4 colors]}}

// `global`: ~/.config/filigrane/theme.toml (shared by Filigrane); `user`: fili-file.toml, which takes precedence
pub fn theme_json_layers(global: &str, user: &str) -> String {
    let defaults = parse_sections(DEFAULT_THEME);
    let global = parse_sections(global);
    let user = parse_sections(user);
    let get = |sections: &Sections, name: &str, key: &str| match sections.get(name).and_then(|s| s.get(key)) {
        Some(Val::Str(v)) => Some(v.clone()),
        _ => None,
    };
    let mut out = String::from("{");
    for (n, mode) in ["dark", "light"].iter().enumerate() {
        if n > 0 {
            out.push(',');
        }
        out.push_str(&format!("{}:{{", json_str(mode)));
        let section = format!("theme.{mode}");
        let mut first = true;
        for (key, kind) in KEYS {
            let found = [(&user, section.as_str()), (&user, "theme"), (&global, section.as_str()), (&global, "theme"), (&defaults, section.as_str()), (&defaults, "theme")]
                .iter()
                .filter_map(|(s, name)| get(s, name, key))
                .find(|v| valid(*kind, v));
            let Some(v) = found else { continue };
            if !first {
                out.push(',');
            }
            first = false;
            out.push_str(&json_str(key));
            out.push(':');
            out.push_str(&if *kind == Kind::Int { v } else { json_str(&v) });
        }
        out.push('}');
    }
    let accents = accents_from(&[&defaults, &global, &user]);
    let list: Vec<String> =
        accents.iter().map(|(n, l)| format!("{}:[{}]", json_str(n), l.iter().map(|c| json_str(c)).collect::<Vec<_>>().join(","))).collect();
    out.push_str(&format!(",\"accents\":{{{}}}}}", list.join(",")));
    out
}

pub fn global_path() -> PathBuf {
    path().with_file_name("theme.toml")
}

pub fn theme_json() -> String {
    let read = |p: PathBuf| std::fs::read_to_string(p).unwrap_or_default();
    theme_json_layers(&read(global_path()), &read(path()))
}

fn state_dir() -> PathBuf {
    let state = env::var("XDG_STATE_HOME").unwrap_or_else(|_| format!("{}/.local/state", env::var("HOME").unwrap_or_default()));
    PathBuf::from(state).join("filigrane")
}

// Light mode: the state of `fili-theme` when there is one, else dark
pub fn read_light() -> bool {
    std::fs::read_to_string(state_dir().join("theme")).is_ok_and(|t| t.trim() == "light")
}

// Accent color (name), "default" by default
pub fn read_accent() -> String {
    std::fs::read_to_string(state_dir().join("accent")).map(|t| t.trim().to_string()).unwrap_or_else(|_| "default".into())
}

// What changes the look: modification times of the files read above, to notice an edit while the window is open
pub fn stamp() -> Vec<Option<std::time::SystemTime>> {
    [path(), global_path(), state_dir().join("theme"), state_dir().join("accent")]
        .iter()
        .map(|p| std::fs::metadata(p).and_then(|m| m.modified()).ok())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_user_file_wins_over_the_global_one_over_the_defaults() {
        let json = theme_json_layers("[theme]\nsize = 15\n", "[theme.dark]\nsize = 16\n");
        assert!(json.contains("\"size\":16"));
        let json = theme_json_layers("[theme]\nsize = 15\n", "");
        assert!(json.contains("\"size\":15"));
        assert!(theme_json_layers("", "").contains("\"background\":\"#1c222b\""));
    }

    #[test]
    fn an_invalid_value_keeps_the_default() {
        assert!(theme_json_layers("", "[theme.dark]\nbackground = \"nope\"\n").contains("\"background\":\"#1c222b\""));
    }
}
