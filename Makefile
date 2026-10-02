CONFIGURATION ?= release

.PHONY: all build test lint format format-check clean run

all: build

build:
	@CONFIGURATION="$(CONFIGURATION)" scripts/build.sh

test:
	@swift run --package-path app -c debug DASTests
	@bash scripts/tests/metadata.sh
	@bash scripts/tests/installer.sh

lint:
	@for script in scripts/*.sh scripts/tests/*.sh; do bash -n "$$script" || exit 1; done
	@bash scripts/check.sh

format:
	@swift format format --in-place --recursive app/Package.swift app/Sources app/Tests

format-check:
	@swift format lint --strict --recursive app/Package.swift app/Sources app/Tests

run: build
	@dist/das

clean:
	@swift package --package-path app clean && rm -rf dist
	@printf 'Build files removed.\n'
