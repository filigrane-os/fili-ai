// Translations: texts are written in English in the QML (Link.tr("Open")) and translated by a flat JSON catalog
// {"English text": "translation"}, looked up in <data dir>/fili-ai/i18n/<language>.json for each XDG data directory (so a
// language can be added without recompiling), then in the catalogs embedded in the binary (i18n/). No catalog or no entry:
// English. Language: FILI_LANG, else the choice of fili-lang ($XDG_STATE_HOME/filigrane/locale), else LC_ALL, LC_MESSAGES, LANG.
use std::{collections::HashMap, env, fs, path::PathBuf, sync::OnceLock};

const EMBEDDED: [(&str, &str); 1] = [("fr", include_str!("../i18n/fr.json"))];

static CATALOG: OnceLock<HashMap<String, String>> = OnceLock::new();

fn lang() -> String {
    if cfg!(test) {
        return "en".into();
    }
    let state = env::var("XDG_STATE_HOME").unwrap_or_else(|_| format!("{}/.local/state", env::var("HOME").unwrap_or_default()));
    let choice = fs::read_to_string(format!("{state}/filigrane/locale")).map(|s| s.trim().to_string()).unwrap_or_default();
    let v = env::var("FILI_LANG")
        .ok()
        .filter(|v| !v.is_empty())
        .or(Some(choice).filter(|v| !v.is_empty()))
        .or_else(|| ["LC_ALL", "LC_MESSAGES", "LANG"].iter().find_map(|k| env::var(k).ok().filter(|v| !v.is_empty())))
        .unwrap_or_default();
    let l: String = v.chars().take_while(|c| !matches!(c, '_' | '.' | '@')).collect();
    if !l.is_empty() && l.chars().all(|c| c.is_ascii_lowercase()) { l } else { "en".into() }
}

fn data_dirs() -> Vec<PathBuf> {
    let home = env::var("HOME").unwrap_or_default();
    let mut dirs = vec![PathBuf::from(env::var("XDG_DATA_HOME").unwrap_or_else(|_| format!("{home}/.local/share")))];
    let xdg = env::var("XDG_DATA_DIRS").unwrap_or_else(|_| "/usr/local/share:/usr/share".into());
    dirs.extend(xdg.split(':').filter(|d| !d.is_empty()).map(PathBuf::from));
    dirs
}

fn catalog() -> &'static HashMap<String, String> {
    CATALOG.get_or_init(|| {
        let lang = lang();
        if lang == "en" {
            return HashMap::new();
        }
        let external = data_dirs().iter().find_map(|d| fs::read_to_string(d.join(format!("fili-ai/i18n/{lang}.json"))).ok());
        let text = external.or_else(|| EMBEDDED.iter().find(|(l, _)| *l == lang).map(|(_, t)| t.to_string()));
        text.and_then(|t| serde_json::from_str::<HashMap<String, String>>(&t).ok()).unwrap_or_default()
    })
}

pub fn tr(s: &str) -> String {
    catalog().get(s).cloned().unwrap_or_else(|| s.to_string())
}

#[cfg(test)]
mod tests {
    // Every text of the QML has an entry in the French catalog, and the catalog keeps no dead entry
    #[test]
    fn the_french_catalog_matches_the_qml() {
        let root = env!("CARGO_MANIFEST_DIR");
        let mut used = std::collections::BTreeSet::new();
        for e in std::fs::read_dir(format!("{root}/qml")).unwrap() {
            let text = std::fs::read_to_string(e.unwrap().path()).unwrap();
            for part in text.split("Link.tr(\"").skip(1) {
                let end = part.find("\")").or_else(|| part.find("\",")).unwrap_or(0);
                used.insert(part[..end].to_string());
            }
        }
        let cat: std::collections::BTreeMap<String, String> = serde_json::from_str(&std::fs::read_to_string(format!("{root}/i18n/fr.json")).unwrap()).unwrap();
        for u in &used {
            assert!(cat.contains_key(u), "no French entry for \"{u}\"");
        }
        for k in cat.keys() {
            assert!(used.contains(k), "the French entry \"{k}\" is not used");
        }
    }
}
