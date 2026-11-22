# fili-ai

Lia, the optional AI assistant of [Filigrane](https://github.com/filigrane-os/filigrane). Filigrane works without it: the
assistant is one client of the file and command contracts of `docs/api.md` of the distribution.

- `fili-ai`: the one command (launcher; hands the drawer verbs to the daemon).
- `fili-ai-daemon`: keeps the sessions, the drawer protocol and the MCP bridge.
- `fili-ai-session`: terminal sessions of the agents (hooks, status line).

Build: `make`, test: `make check`. The window (Qt Quick, layer-shell through `layer-shell-qt`) is ported from the shell next.
