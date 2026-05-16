SHELL := /bin/sh

.PHONY: help setup test build release copy deploy dev app run patch minor web

help:
	@echo "Source:"
	@echo "  make setup    install Crystal deps"
	@echo "  make test     run specs"
	@echo "  make build    test + build CLI binary"
	@echo "  make release  test + build CLI binary (--release)"
	@echo "  make copy     copy binary to /usr/local/bin"
	@echo "  make deploy   release + copy"
	@echo "  make patch    bump patch version (x.y.Z)"
	@echo "  make minor    bump minor version (x.Y.0)"
	@echo ""
	@echo "Example app:"
	@echo "  make dev      lune dev in exampleapp/"
	@echo "  make app      lune build in exampleapp/"
	@echo "  make run      lune run in exampleapp/"
	@echo ""
	@echo "Docs:"
	@echo "  make web      run website dev server"

# ── Source ───────────────────────────────────────────────────────────────────

setup:
	shards install

test:
	crystal spec -D lune_native_test_mock

build:
	$(MAKE) test && shards build

release:
	$(MAKE) test && shards build --release

copy:
	cp ./bin/lune /usr/local/bin/lune

deploy:
	$(MAKE) release && $(MAKE) copy

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
	cd exampleapp && lune dev

app:
	cd exampleapp && lune build

run:
	cd exampleapp && lune run

# ── Docs ─────────────────────────────────────────────────────────────────────

web:
	npm run docs:dev
