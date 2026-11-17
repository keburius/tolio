#!/bin/bash
# Packages the universal Release build into dist/Tolio-<version>.dmg
# (Tolio.app + an Applications shortcut, laid out over a background picture,
# with the Tolio disk icon) and writes its SHA-256 next to it. Arranging the
# window uses Finder, so macOS may ask once to let Terminal control Finder.
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
VOL="Tolio $VERSION"
MOUNT="/Volumes/$VOL"
RW="build/$NAME-rw.dmg"
/bin/rm -f "$RW"

# A disk with the same name must not be mounted (e.g. a downloaded copy):
# eject it so the new one mounts at the expected path. Ejecting deletes nothing.
if [ -d "$MOUNT" ]; then
    echo "Ejecting the mounted \"$VOL\" disk first"
    hdiutil detach -quiet "$MOUNT" || hdiutil detach -quiet -force "$MOUNT"
fi

# 1. A writable disk with the app, the Applications shortcut, the background
#    and the disk icon.
mkdir -p "$STAGE/.background"
cp Scripts/dmg/background.tiff "$STAGE/.background/background.tiff"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
hdiutil create -quiet -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -size 80m "$RW"
/bin/rm -rf "$STAGE"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$RW"

# 2. Lay out the Finder window: fixed size, no toolbar, big icons, Tolio left,
#    Applications right (positions match Scripts/dmg/make-background.swift).
SetFile -a C "$MOUNT"            # use .VolumeIcon.icns as the disk icon
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 568}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "Tolio.app" of container window to {170, 190}
        set position of item "Applications" of container window to {490, 190}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
sync
/bin/rm -rf "$MOUNT/.fseventsd"
hdiutil detach -quiet "$MOUNT" || { sleep 2; hdiutil detach -quiet -force "$MOUNT"; }

# 3. Compress into the final read-only disk image.
hdiutil convert -quiet "$RW" -format UDZO -imagekey zlib-level=9 -o "$DIST/$NAME.dmg"
/bin/rm -f "$RW"

(cd "$DIST" && shasum -a 256 "$NAME.dmg" > "$NAME.dmg.sha256")
cp "$DIST/$NAME.dmg" "$DIST/Tolio.dmg"
SIGNER=$(codesign -dvv "$APP" 2>&1 | sed -n 's/^Authority=//p' | head -1)
echo "Built $DIST/$NAME.dmg ($(du -h "$DIST/$NAME.dmg" | cut -f1), $ARCHS)"
echo "Signed by: ${SIGNER:-ad-hoc (no certificate)}"
cat "$DIST/$NAME.dmg.sha256"
