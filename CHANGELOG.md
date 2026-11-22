# Changelog

## 0.1.0

First release of Lia (fili-ai) as an application of its own, out of the Filigrane distribution.

- The window (`fili-ai-window`): a drawer on the right edge (Qt Quick on the layer-shell, docked or floating, resizable), the
  session rail with application icons, the small floating field of "Ask Lia…", notifications for permissions and finished
  turns, the application noted by Mod+Y as a chip, files attached by drop or paste, rename, All sessions, the About card, the
  Debug panel and its incidents, the theme of Filigrane (light mode, accent) and a French catalog.
- One instance driven by commands: `fili-ai toggle|show|hide|here|ask|act NAME`, `fili-ai ctl`.
- The daemon (`fili-ai-daemon`) and the terminal sessions (`fili-ai-session`), moved with their history.
- The package brings its bar module, its fallback menu, its `ctl` catalog, the incident handler, the prompts and the briefs
  (`lia/`, the older `rob/` is still read).
