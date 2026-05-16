SHELL := /bin/bash

BROWSER ?= chromium
URLS ?= benchmarks/urls.txt
MARKETING_URLS ?= benchmarks/urls-marketing.txt
SMOKE_ITERATIONS ?= 1
MARKETING_ITERATIONS ?= 3

.DEFAULT_GOAL := help

.PHONY: help deps deps-ci docs-deps docs-deps-ci docs-dev docs-build docs-preview run test test-claims test-all package package-claims package-fast \
	bench-plain bench-browser bench-compare bench-claim-gate-smoke bench-smoke \
	bench-plain-marketing bench-browser-marketing bench-compare-marketing \
	bench-claim-gate-marketing bench-publish-marketing bench-update-readme bench-marketing \
	bench-power-measure bench-power-claim-gate bench-power-publish bench-power-postprocess bench-power

help:
	@printf "Plain commands\n"
	@printf "\n"
	@printf "  make deps                     Install Node benchmark dependencies\n"
	@printf "  make deps-ci                  Install locked Node dependencies for CI\n"
	@printf "  make docs-deps                Install docs site dependencies\n"
	@printf "  make docs-dev                 Run the docs site locally\n"
	@printf "  make docs-build               Build the docs site\n"
	@printf "  make run                      Run the macOS app with SwiftPM\n"
	@printf "  make test                     Run Swift tests\n"
	@printf "  make test-claims              Run Node claim/architecture tests\n"
	@printf "  make test-all                 Run Swift and claim tests\n"
	@printf "  make package                  Build app, zip, and DMG\n"
	@printf "  make package-claims           Package with claim tests enabled\n"
	@printf "  make package-fast             Package without running tests\n"
	@printf "  make bench-smoke              Run local smoke benchmark comparison\n"
	@printf "  make bench-marketing          Run full marketing benchmark gate\n"
	@printf "  sudo make bench-power-measure Measure power with powermetrics\n"
	@printf "  make bench-power-postprocess  Validate/publish latest power result\n"

deps:
	npm install

deps-ci:
	npm ci

docs-deps:
	npm --prefix docs install

docs-deps-ci:
	npm --prefix docs ci

docs-dev:
	npm --prefix docs run dev

docs-build:
	npm --prefix docs run build

docs-preview:
	npm --prefix docs run preview

run:
	swift run Plain

test:
	swift test

test-claims:
	node --test benchmarks/tests/*.test.mjs

test-all: test test-claims

package:
	./scripts/package-release.sh

package-claims:
	RUN_CLAIM_TESTS=1 ./scripts/package-release.sh

package-fast:
	SKIP_TESTS=1 ./scripts/package-release.sh

bench-plain:
	swift run PlainBench -- --urls $(URLS) --iterations $(SMOKE_ITERATIONS) --mode both --out benchmarks/results/plainview.json

bench-browser:
	node benchmarks/browser-baseline.mjs --urls $(URLS) --iterations $(SMOKE_ITERATIONS) --browser $(BROWSER) --out benchmarks/results/browser-$(BROWSER).json

bench-compare:
	node benchmarks/compare.mjs --plainview benchmarks/results/plainview.json --browser benchmarks/results/browser-$(BROWSER).json --out benchmarks/results/comparison.json --policy smoke

bench-claim-gate-smoke:
	node benchmarks/claim-gate.mjs --comparison benchmarks/results/comparison.json --policy smoke

bench-smoke: bench-plain bench-browser bench-compare bench-claim-gate-smoke

bench-plain-marketing:
	swift run PlainBench -- --urls $(MARKETING_URLS) --iterations $(MARKETING_ITERATIONS) --mode both --out benchmarks/results/plainview-marketing.json

bench-browser-marketing:
	node benchmarks/browser-baseline.mjs --urls $(MARKETING_URLS) --iterations $(MARKETING_ITERATIONS) --browser $(BROWSER) --out benchmarks/results/browser-marketing.json

bench-compare-marketing:
	node benchmarks/compare.mjs --plainview benchmarks/results/plainview-marketing.json --browser benchmarks/results/browser-marketing.json --out benchmarks/results/comparison-marketing.json --policy marketing

bench-claim-gate-marketing:
	node benchmarks/claim-gate.mjs --comparison benchmarks/results/comparison-marketing.json --policy marketing

bench-publish-marketing:
	node benchmarks/publish-approved.mjs --comparison benchmarks/results/comparison-marketing.json --plainview benchmarks/results/plainview-marketing.json --browser benchmarks/results/browser-marketing.json --urls $(MARKETING_URLS) --out-dir benchmarks/approved

bench-update-readme:
	node benchmarks/update-readme-claims.mjs --comparison benchmarks/approved/latest/comparison-marketing.json --readme README.md --report benchmarks/approved/latest/comparison-marketing.md

bench-marketing: bench-plain-marketing bench-browser-marketing bench-compare-marketing bench-claim-gate-marketing bench-publish-marketing bench-update-readme

bench-power-measure:
	node benchmarks/power-runner.mjs --urls $(MARKETING_URLS) --iterations $(MARKETING_ITERATIONS) --out benchmarks/results/power-marketing.json --plainview-out benchmarks/results/plainview-power.json --browser-out benchmarks/results/browser-power.json

bench-power-claim-gate:
	node benchmarks/power-claim-gate.mjs --power benchmarks/results/power-marketing.json --policy marketing

bench-power-publish:
	node benchmarks/publish-approved.mjs --comparison benchmarks/approved/latest/comparison-marketing.json --plainview benchmarks/approved/latest/plainview-marketing.json --browser benchmarks/approved/latest/browser-marketing.json --urls benchmarks/approved/latest/urls-marketing.txt --power benchmarks/results/power-marketing.json --out-dir benchmarks/approved

bench-power-postprocess: bench-power-claim-gate bench-power-publish bench-update-readme

bench-power: bench-power-measure bench-power-postprocess
