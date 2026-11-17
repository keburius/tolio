<p align="center">
  <img src="App/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="128" height="128" alt="Tolio icon">
</p>

<h1 align="center">Tolio</h1>

<p align="center">The shortcuts your Mac is missing, in one small menu bar app.<br>
Free, private, and everything stays on your Mac.</p>

---

## What it does

| | |
|---|---|
| **Launcher** | ⌃⌥Space opens apps, files, settings and Tolio's commands. It also does math and currency conversions. |
| **Clipboard History** | ⌃⌥V shows what you copied, with picture previews. Pin items and keep text snippets. |
| **Screenshots & Recording** | ⇧⌘4 captures an area or a window, then opens an editor with a brush, boxes, numbered steps and text. Untouched captures are copied automatically after 3 seconds. You can record the screen with or without your microphone, pause, and mute. |
| **Capture Text** | ⇧⌘2 copies the text in any part of the screen, and reads QR codes and barcodes. |
| **Sticky Notes** | Glass notes on your desktop. Add one with ⌃⌥⌘N or by right-clicking the desktop. |
| **Window Layouts** | ⌃⌥←/→/↑/↓ for halves, ⌃⌥D/F/G for thirds, ⌃⌥↩ to maximize. You can also drag windows to screen edges. |
| **Window Switcher** | Hold ⌥ and press Tab to jump to any window, not just any app. |
| **Energy Mode** | ⌃⌥⌘A keeps your Mac awake, for a set time or while certain apps run. |
| **Lock Keyboard** | ⌃⌥⌘L locks the keyboard so you can wipe it clean. Unlock it with the mouse. |
| **Shortcut cheat sheet** | ⌃⌥⌘/ shows the current app's menu shortcuts. |
| **Text selection actions** | Select text to search the web, open links or translate. |
| **System Stats** | CPU, memory and disk in the menu bar. |

Turn each feature on or off in **Settings**. ⌃⌥⌘M opens the control panel from anywhere, and you can change every shortcut in Settings → Shortcuts.

## Install

Requires **macOS 14 (Sonoma) or later**, on Apple silicon or Intel.

1. Download **`Tolio-<version>.dmg`** from the [latest release](../../releases/latest).
2. Open it and drag **Tolio** onto **Applications**.
3. Open Tolio from Applications. The first time, macOS stops it, because Tolio isn't notarized by Apple (that needs a paid developer account; Tolio is a free hobby project). To allow it once:
   - **macOS 15 or later:** click **Done**, then open **System Settings → Privacy & Security**. Scroll down to *"Tolio" was blocked…* and click **Open Anyway**, then confirm with your password.
   - **macOS 14:** right-click (or Control-click) Tolio in Applications, choose **Open**, then click **Open**.

   You only do this once. After that Tolio opens normally.
4. The welcome screen walks you through the rest: choosing features and granting permissions.

<details>
<summary>Prefer Terminal?</summary>

After copying Tolio to Applications, this removes the "downloaded from the internet" flag so macOS doesn't stop it:

```sh
xattr -dr com.apple.quarantine /Applications/Tolio.app
```
</details>

### Check your download (optional)

Each release lists a SHA-256 checksum. Compare it with:

```sh
shasum -a 256 ~/Downloads/Tolio-*.dmg
```

## Permissions

macOS asks you to allow these yourself. Tolio only asks for what the features you turn on need.

| Permission | Used for |
|---|---|
| **Accessibility** | Moving windows, typing snippets, reading selected text and menus, and global shortcuts |
| **Screen Recording** | Screenshots, screen recording, Capture Text and window previews |
| **Microphone** | Only when you record the screen with the microphone turned on |
| **Finder extension** | "New Sticky Note" in the desktop's right-click menu. Turn on **Tolio** under System Settings → General → Login Items & Extensions → Finder |

## Privacy

- **Nothing you do leaves your Mac.** No accounts, no analytics, no tracking.
- The only thing Tolio downloads is **currency rates**: a small public file from the European Central Bank and the National Bank of Georgia, at most every 6 hours, when you open the Launcher. Nothing about you is sent, and you can switch it off in Settings → Launcher.
- Clipboard contents, notes and text you select or capture are never written to logs.
- Files Tolio deletes, such as recordings you discard and old clipboard images, go to the **Trash** and are never erased outright.

## Uninstall

1. Click Tolio's menu bar icon, then **Quit Tolio**.
2. Move **Tolio** from Applications to the Trash.
3. Optional: to remove your data too, move these to the Trash:
   - `~/Library/Application Support/com.george.tolio`
   - `~/Library/Preferences/com.george.tolio.plist`
   - `~/Library/Containers/com.george.tolio.FinderNote`
   - `~/Library/Caches/com.george.tolio`
4. Optional: remove Tolio from the lists in System Settings → Privacy & Security.

## Build from source

You need Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
make test   # build and run all tests
make run    # build and start the Debug app
make dmg    # universal Release build → dist/Tolio-<version>.dmg (+ .sha256)
```

A fresh clone builds ad-hoc signed. To keep permissions across rebuilds, add your own signing identity in `Config/Signing.local.xcconfig` (see `Config/Base.xcconfig`).

Tolio is written in Swift 6 with SwiftUI and AppKit. Each feature is its own module in `OmniKit/` (the project's original code name).

## Credits

- [GRDB.swift](https://github.com/groue/GRDB.swift) by Gwendal Roué (MIT License), vendored in `Vendor/GRDB`.
