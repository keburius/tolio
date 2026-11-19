SHELL := /bin/bash
PROJECT := AllSet.xcodeproj
SCHEME  := AllSet
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/All Set.app
PROC    := All Set
XCB     := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED)

.PHONY: gen build test run release dmg downloads clean strings

gen:
	@xcodegen generate --quiet

# Rebuilds the String Catalog from the L10n accessors.
strings:
	@python3 Scripts/gen-strings.py

build: gen
	@mkdir -p build
	@set -o pipefail; $(XCB) build 2>&1 | tee build/build.log | grep -E '(error|warning):|BUILD (SUCCEEDED|FAILED)' || exit 1
	@Scripts/check-warnings.sh build/build.log
	@Scripts/check-strings.sh

test: gen
	@mkdir -p build
	@set -o pipefail; $(XCB) test 2>&1 | tee build/test.log | grep -E '(error|warning):|✘|Test run with|TEST (SUCCEEDED|FAILED)|\*\* TEST' || exit 1
	@Scripts/check-warnings.sh build/test.log
	@Scripts/check-strings.sh

release: gen
	@mkdir -p build
	@set -o pipefail; $(XCB) -configuration Release ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO build 2>&1 | tee build/release.log | grep -E '(error|warning):|BUILD (SUCCEEDED|FAILED)' || exit 1
	@Scripts/check-warnings.sh build/release.log

# Universal Release build packaged as dist/AllSet-<version>.dmg (+ .sha256),
# ready to attach to a GitHub release.
dmg: release
	@Scripts/make-dmg.sh

# How many times each release file was downloaded from GitHub.
downloads:
	@python3 Scripts/downloads.py

# Waits up to 5 s for a running All Set to exit; launching while it is still
# shutting down makes LaunchServices fail with -600.
run: build
	@pkill -x "$(PROC)" || true
	@for i in $$(seq 1 50); do pgrep -x "$(PROC)" >/dev/null || break; sleep 0.1; done
	@if pgrep -x "$(PROC)" >/dev/null; then echo "$(PROC) did not exit; sending SIGKILL"; pkill -9 -x "$(PROC)"; sleep 0.5; fi
	@# LaunchServices can report -600 yet still launch the app. Retry only if
	@# it isn't running, or the second open counts as a re-open and shows Settings.
	@open "$(APP)" || { sleep 1; pgrep -x "$(PROC)" >/dev/null || { echo "open failed; retrying"; open "$(APP)"; }; }

clean:
	rm -rf build AllSet.xcodeproj
