#!/bin/bash
# Packages the universal Release build into dist/Tolio-<version>.dmg
# (Tolio.app + an Applications shortcut) and writes its SHA-256 next to it.
# Also writes dist/Tolio.dmg, the same file under a fixed name: attached to
# each GitHub release, it makes .../releases/latest/download/Tolio.dmg (the
# website's Download button) always point at the newest version.
# Run through `make dmg`, which builds the Release app first.
set -euo pipefail

APP="build/DerivedData/Build/Products/Release/Tolio.app"
[ -d "$APP" ] || { echo "No Release build at $APP (run: make release)"; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
NAME="Tolio-$VERSION"
DIST="dist"
STAGE="build/dmg-stage"

# Sanity checks: universal binary, valid signature.
ARCHS=$(lipo -archs "$APP/Contents/MacOS/Tolio")
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "Not universal: $ARCHS"; exit 1; }
codesign --verify --deep --strict "$APP"

# Fresh staging folder (only build products live here).
/bin/rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
ditto "$APP" "$STAGE/Tolio.app"
ln -s /Applications "$STAGE/Applications"

if [ -e "$DIST/$NAME.dmg" ]; then
    # Never delete outright: an older build of the same version goes to the Trash.
    trash "$DIST/$NAME.dmg" "$DIST/$NAME.dmg.sha256" "$DIST/Tolio.dmg" 2>/dev/null || true
fi
hdiutil create -quiet -volname "Tolio $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO -imagekey zlib-level=9 "$DIST/$NAME.dmg"
/bin/rm -rf "$STAGE"

(cd "$DIST" && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")
cp "$DIST/$NAME.dmg" "$DIST/Tolio.dmg"
SIGNER=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
echo "Built $DIST/$NAME.dmg ($(du -h "$DIST/$NAME.dmg" | cut -f1), $ARCHS)"
echo "Signed by: ${SIGNER:-ad-hoc (no certificate)}"
cat "$DIST/$NAME.dmg.sha256"
