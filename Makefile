SHELL := /bin/sh

.PHONY: help setup test build release deploy dev app copy patch minor web

help:
	@echo "Targets:"
	@echo "  make setup    # install Crystal deps"
	@echo "  make test     # run specs"
	@echo "  make build    # test + build CLI binary"
	@echo "  make release  # test + build CLI binary with --release"
	@echo "  make deploy   # release + copy to /usr/local/bin"
	@echo "  make dev      # run lune dev via crystal run"
	@echo "  make app      # run lune build via crystal run"
	@echo "  make patch    # bump patch version (x.y.Z)"
	@echo "  make minor    # bump minor version (x.Y.0)"
	@echo "  make web      # run website dev server"

setup:
	shards install

test:
	crystal spec

build:
	$(MAKE) test && shards build

release:
	$(MAKE) test && shards build --release

copy:
	cp ./bin/lune /usr/local/bin/lune

deploy:
	$(MAKE) release && $(MAKE) copy

dev:
	crystal run bin/lune.cr -- dev

app:
	crystal run bin/lune.cr -- build

web:
	npm run docs:dev

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
	minor=$$(echo $$current | cut -d. -f2); \
	next="$$major.$$((minor + 1)).0"; \
	sed -i.bak "s/^version: .*/version: $$next/" shard.yml && rm shard.yml.bak; \
	sed -i.bak "s/VERSION = \".*\"/VERSION = \"$$next\"/" src/lune.cr && rm src/lune.cr.bak; \
	sed -i.bak "s/version: ~> .*/version: ~> $$next/" website/getting-started.md && rm website/getting-started.md.bak; \
	sed -i.bak "s/const version = '.*'/const version = '$$next'/" website/.vitepress/config.ts && rm website/.vitepress/config.ts.bak; \
	echo "Bumped $$current → $$next"
