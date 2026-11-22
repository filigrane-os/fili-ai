# fili-ai (Lia, the assistant of Filigrane): build and install.
#
#   make                       build the release binaries
#   make test                  unit tests
#   make check                 everything automated (tests, API validator)
#   sudo make install          install under /usr/local (PREFIX=/usr for a system package)
#   make install DESTDIR=pkg PREFIX=/usr      stage into a directory (packagers)
#   make install-data PREFIX=~/.local         everything but the binaries
#
# Filigrane works without this package: the assistant is one client of the contracts of docs/api.md.
PREFIX ?= /usr/local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share
CARGO ?= cargo
TARGET_DIR ?= $(if $(CARGO_TARGET_DIR),$(CARGO_TARGET_DIR),target)
BINS = fili-ai-daemon fili-ai-session fili-ai-window
# cxx-qt finds Qt through qmake. QMAKE overrides the search below (Qt 6 only)
QMAKE ?= $(firstword $(wildcard /usr/lib/qt6/bin/qmake6 /usr/lib64/qt6/bin/qmake6 /usr/lib/qt6/bin/qmake /usr/lib64/qt6/bin/qmake) $(shell command -v qmake6 qmake-qt6 2>/dev/null))
export QMAKE

.PHONY: all build test check install install-data uninstall

all: build

build:
	$(CARGO) build --release --locked

test:
	$(CARGO) test --release --locked

check: build test
	python3 -I scripts/fili-api-lint --app crates/fili-ai-window

install: build install-data
	for b in $(BINS); do install -Dm755 $(TARGET_DIR)/release/$$b $(DESTDIR)$(BINDIR)/$$b; done

install-data:
	install -Dm755 bin/fili-ai $(DESTDIR)$(BINDIR)/fili-ai
	install -Dm644 data/fili-ai.desktop $(DESTDIR)$(DATADIR)/applications/fili-ai.desktop
	if [ -d data/icons ]; then cp -r data/icons $(DESTDIR)$(DATADIR)/; fi
	install -Dm644 fili-ai.toml $(DESTDIR)$(DATADIR)/doc/fili-ai/fili-ai.toml
	install -Dm644 lib/i18n.sh $(DESTDIR)$(DATADIR)/fili-ai/lib/i18n.sh
	install -Dm644 lib/i18n/fr.sh $(DESTDIR)$(DATADIR)/fili-ai/lib/i18n/fr.sh
	install -Dm644 data/prompts/chat-prompt.md $(DESTDIR)$(DATADIR)/fili-ai/chat-prompt.md
	install -Dm644 data/prompts/lia/_default.md $(DESTDIR)$(DATADIR)/fili-ai/lia/_default.md
	install -Dm644 LICENSE $(DESTDIR)$(DATADIR)/licenses/fili-ai/LICENSE
	for f in licenses/*; do install -Dm644 "$$f" $(DESTDIR)$(DATADIR)/licenses/fili-ai/$$(basename "$$f"); done
	mkdir -p $(DESTDIR)$(DATADIR)/filigrane/shell
	cp -r crates/fili-ai-window/shell/. $(DESTDIR)$(DATADIR)/filigrane/shell/

uninstall:
	for b in $(BINS) fili-ai; do rm -f $(DESTDIR)$(BINDIR)/$$b; done
	rm -rf $(DESTDIR)$(DATADIR)/licenses/fili-ai $(DESTDIR)$(DATADIR)/fili-ai $(DESTDIR)$(DATADIR)/doc/fili-ai
	rm -f $(DESTDIR)$(DATADIR)/applications/fili-ai.desktop
	rm -f $(DESTDIR)$(DATADIR)/filigrane/shell/ctl/fili-ai.json $(DESTDIR)$(DATADIR)/filigrane/shell/appmenu/fili-ai.json $(DESTDIR)$(DATADIR)/filigrane/shell/lia/fili-ai.md $(DESTDIR)$(DATADIR)/filigrane/shell/incident/lia.toml
