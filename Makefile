SHELL := /bin/sh

.PHONY: help setup test build release deploy dev app copy

help:
	@echo "Targets:"
	@echo "  make setup    # install Crystal + frontend deps"
	@echo "  make test     # run specs"
	@echo "  make build    # test + build CLI binary"
	@echo "  make release  # test + build CLI binary with --release"
	@echo "  make deploy   # release + copy to /usr/local/bin"
	@echo "  make dev      # run lune dev via crystal run"
	@echo "  make app      # run lune build via crystal run"

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
