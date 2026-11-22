# fili-ai

Lia, the optional AI assistant of [Filigrane](https://github.com/filigrane-os/filigrane). Filigrane works without it: the
assistant is one client of the file and command contracts of `docs/api.md` of the distribution.

| Program | Role |
|---|---|
| `fili-ai` | the one command (launcher): `toggle`, `show`, `hide`, `here [TEXT]`, `ask TEXT`, `act NAME`, `sessions`, `send`, `use`, `install`, `update`, `status` |
| `fili-ai-window` | the window: a drawer on the right edge (Qt Quick on the layer-shell, through `layer-shell-qt`), the small floating field, the About card and the Debug panel. One instance at a time, driven by commands; it ends when it is closed and no agent works for it |
| `fili-ai-daemon` | keeps the sessions and their history, talks to the agent (Claude Code, Codex, opencode), serves the permission requests |
| `fili-ai-session` | the terminal sessions of the agents (hooks and status line, state for the bar) |

What the package brings to the desktop (`make install-data`): the launcher and its catalog, the `.desktop`, the bar module `agent`
(`shell/fili-bar/agent/`), the fallback menu, the `ctl` catalog (`fili-ai ctl`, `fili-api show fili-ai`), the incident handler
("Ask Lia"), the prompts and the briefs (`data/prompts/`, `shell/lia/<app_id>.md`).

Build: `make`, test: `make check` (unit tests and the API validator). Settings: `~/.config/filigrane/fili-ai.toml`
(`fili-ai.toml` of this repository documents them); the theme follows `theme.toml` and `fili-theme`.

Needs Qt 6 (declarative, wayland), `layer-shell-qt`, `wl-clipboard`, `libnotify`.
