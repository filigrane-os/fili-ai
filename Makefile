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
BINS = fili-ai-daemon fili-ai-session

.PHONY: all build test check install install-data uninstall

all: build

build:
	$(CARGO) build --release --locked

test:
	$(CARGO) test --release --locked

check: build test
	@if [ -d shell/ctl ]; then python3 -I scripts/fili-api-lint --app .; fi

install: build install-data
	for b in $(BINS); do install -Dm755 $(TARGET_DIR)/release/$$b $(DESTDIR)$(BINDIR)/$$b; done

install-data:
	install -Dm755 bin/fili-ai $(DESTDIR)$(BINDIR)/fili-ai
	install -Dm644 LICENSE $(DESTDIR)$(DATADIR)/licenses/fili-ai/LICENSE
	if [ -d shell ]; then mkdir -p $(DESTDIR)$(DATADIR)/filigrane/shell && cp -r shell/. $(DESTDIR)$(DATADIR)/filigrane/shell/; fi

uninstall:
	for b in $(BINS) fili-ai; do rm -f $(DESTDIR)$(BINDIR)/$$b; done
	rm -rf $(DESTDIR)$(DATADIR)/licenses/fili-ai
