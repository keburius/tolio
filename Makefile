SHELL := /bin/bash
PROJECT := Tolio.xcodeproj
SCHEME  := Tolio
DERIVED := build/DerivedData
APP     := $(DERIVED)/Build/Products/Debug/Tolio.app
XCB     := xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' -derivedDataPath $(DERIVED)

.PHONY: gen build test run release clean strings

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

# Waits up to 5 s for a running Tolio to exit; launching while it is still
# shutting down makes LaunchServices fail with -600.
run: build
	@pkill -x Tolio || true
	@for i in $$(seq 1 50); do pgrep -x Tolio >/dev/null || break; sleep 0.1; done
	@if pgrep -x Tolio >/dev/null; then echo "Tolio did not exit; sending SIGKILL"; pkill -9 -x Tolio; sleep 0.5; fi
	@# LaunchServices can report -600 yet still launch the app. Retry only if
	@# it isn't running, or the second open counts as a re-open and shows Settings.
	@open $(APP) || { sleep 1; pgrep -x Tolio >/dev/null || { echo "open failed; retrying"; open $(APP); }; }

clean:
	rm -rf build Tolio.xcodeproj
