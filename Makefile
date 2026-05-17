SHELL := /bin/sh

.PHONY: help setup test build release copy deploy dev app run patch minor web clean

help:
	@echo "Source:"
	@echo "  make setup    install Crystal deps"
	@echo "  make test     run specs"
	@echo "  make build    test + build CLI binary"
	@echo "  make release  test + build CLI binary (--release)"
	@echo "  make copy     copy binary to /usr/local/bin"
	@echo "  make deploy   release + copy"
	@echo "  make clean    remove build artifacts"
	@echo "  make patch    bump patch version (x.y.Z)"
	@echo "  make minor    bump minor version (x.Y.0)"
	@echo ""
	@echo "Example app:"
	@echo "  make dev      lune dev in demo/"
	@echo "  make app      lune build in demo/"
	@echo "  make run      lune run in demo/"
	@echo ""
	@echo "Docs:"
	@echo "  make web      run website dev server"

# ── Source ───────────────────────────────────────────────────────────────────

setup:
	shards install

CRYSTAL_FLAGS := -Dpreview_mt -Dexecution_context

test:
	crystal spec -D lune_native_test_mock $(CRYSTAL_FLAGS)

build:
	$(MAKE) test && shards build $(CRYSTAL_FLAGS)

release:
	$(MAKE) test && shards build --release $(CRYSTAL_FLAGS)

copy:
	cp ./bin/lune /usr/local/bin/lune

deploy:
	$(MAKE) release && $(MAKE) copy

clean:
	rm -rf bin/lune bin/lune.dwarf
	rm -rf demo/build demo/.lune-dev demo/*.dwarf

patch:
	@current=$$(grep '^version:' shard.yml | sed 's/version: //'); \
	major=$$(echo $$current | cut -d. -f1); \
	minor=$$(echo $$current | cut -d. -f2); \
	patch=$$(echo $$current | cut -d. -f3); \
	next="$$major.$$minor.$$((patch + 1))"; \
	sed -i.bak "s/^version: .*/version: $$next/" shard.yml && rm shard.yml.bak; \
	sed -i.bak "s/VERSION = \".*\"/VERSION = \"$$next\"/" src/lune.cr && rm src/lune.cr.bak; \
	sed -i.bak "s/version: ~> .*/version: ~> $$next/" website/getting-started.md && rm website/getting-started.md.bak; \
	sed -i.bak "s/const version = '.*'/const version = '$$next'/" website/.vitepress/config.ts && rm website/.vitepress/config.ts.bak; \
	echo "Bumped $$current → $$next"

minor:
	@current=$$(grep '^version:' shard.yml | sed 's/version: //'); \
	major=$$(echo $$current | cut -d. -f1); \
	cur_minor=$$(echo $$current | cut -d. -f2); \
	next="$$major.$$((cur_minor + 1)).0"; \
	sed -i.bak "s/^version: .*/version: $$next/" shard.yml && rm shard.yml.bak; \
	sed -i.bak "s/VERSION = \".*\"/VERSION = \"$$next\"/" src/lune.cr && rm src/lune.cr.bak; \
	sed -i.bak "s/version: ~> .*/version: ~> $$next/" website/getting-started.md && rm website/getting-started.md.bak; \
	sed -i.bak "s/const version = '.*'/const version = '$$next'/" website/.vitepress/config.ts && rm website/.vitepress/config.ts.bak; \
	echo "Bumped $$current → $$next"

# ── Example app ──────────────────────────────────────────────────────────────

dev:
	cd demo && lune dev

app:
	cd demo && lune build

run:
	cd demo && lune run

# ── Docs ─────────────────────────────────────────────────────────────────────

web:
	npm run docs:dev
