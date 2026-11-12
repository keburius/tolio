# Omni — Implementation Plan

Status: **approved. Phases 0–5 done** (see §8).

## 0. Environment found

| Item | State |
|---|---|
| Xcode | 26.1 (17B55), Swift 6.2.1 |
| Host OS | macOS 27.0.1, arm64 |
| XcodeGen | 2.46.0 via Homebrew (build tool only) |
| libarchive | The SDK ships `libarchive.tbd` but **no headers**. See decision D4 |
| Signing | Apple Development, Personal Team `M6TAWX2WCS`, pinned by SHA-1 in git-ignored `Config/Signing.local.xcconfig`. Without that file builds fall back to ad-hoc |

## 1. Repository layout

```
MC/
├── project.yml                  # XcodeGen spec: app target, test scheme, signing
├── Makefile                     # make gen | build | test | run | lint-warnings
├── PLAN.md
├── App/                         # Thin app target, composition root only
│   ├── OmniApp.swift            # @main, NSApplicationDelegateAdaptor
│   ├── AppDelegate.swift        # Builds services, registers features
│   ├── StatusItemController.swift
│   ├── SettingsWindowController.swift
│   ├── Info.plist               # LSUIElement=YES, usage strings
│   └── Omni.entitlements        # hardened runtime, no sandbox
├── OmniKit/                     # Local Swift package
│   ├── Package.swift
│   ├── Sources/<Module>/...
│   └── Tests/<Module>Tests/...
└── Scripts/
    ├── build-libarchive.sh      # universal static lib (Phase 10)
    └── notarize.sh              # Developer ID sign + notarytool
```

## 2. OmniKit modules

Dependency rule: feature modules depend on `OmniCore` plus the platform kits they need, never on each other. Features talk to each other only through `CommandRegistry` and small protocols defined in `OmniCore`.

| Module | Role | Depends on |
|---|---|---|
| `OmniCore` | `Feature` protocol, `FeatureRegistry`, `Lifetime`, `SettingsStore`, `Log`, `Permission`, `Command`/`CommandRegistry`, `KeyCombo`/`HotkeyBindings`. Foundation only, except `Feature.makeSettingsView()` returning `AnyView` | none |
| `OmniPlatform` | `HotkeyManager` + `CarbonHotkeyBackend`, `PermissionsManager`, `LaunchAtLogin`, `HUD`, `HotkeyRecorderView`, `DirectoryWatcher` (FSEvents), `EventTap` (fail-open), `KeySender`, `PasteboardSnapshot`/`TemporaryPasteboard`, `AXWindow` (uses the approved private `_AXUIElementGetWindow`), `ScreenFrames`, `PowerAssertion`. Later: `FailOpenEventTap`, `AXElement`, `PasteboardSnapshot`, `FloatingPanel` | OmniCore |
| `FeatureDiagnostics` | Test hotkey + palette command, proves the plumbing | Core, Platform |
| `FeaturePalette` | Launcher: `Logic/` (FuzzyMatcher, PaletteRanker, UsageHistory, Calculator, QuantityQuery, UnitConversion, CurrencyRates/ECBRateParser, CurrencyRateStore, QuickAnswerEngine, AppScanner, SettingsPaneCatalog) and `UI/` (PaletteFeature, PaletteController/PalettePanel, PaletteView, view model) | Core, Platform |
| `FeatureClipboard` | Two features: Clipboard History (`ClipCapturePolicy`, `ClipboardStore` on GRDB + FTS5, `ClipboardMonitor`, palette provider) and Snippets (`KeystrokeBuffer`, `PlaceholderExpander`, `SnippetEngine`) | Core, Platform, **GRDB 7.12.0 vendored in `Vendor/GRDB`** |
| `FeatureWindows` | `Logic/` (WindowAction, ScreenGeometry, WindowLayout, RestoreHistory, SnapZones) and `Runtime/` (WindowManager, DragSnapper + SnapPreview), WindowsFeature | Core, Platform |
| `FeatureSwitcher` | `Logic/` (WindowListBuilder, RecencyTracker + SwitcherOrdering, SwitcherStateMachine), `Runtime/` (WindowCatalog, FocusTracker, SwitcherKeyTap, ThumbnailProvider), `UI/` (SwitcherFeature, SwitcherController, SwitcherView) | Core, Platform |
| `FeatureKeepAwake` | KeepAwakePolicy (pure), KeepAwakeFeature (manual session + while-app-running rules) | Core, Platform |
| `FeatureKeyboardClean` | CleaningSession (pure), CleaningController (filtering tap, overlays, watchdog) | Core, Platform |
| `FeatureSystemStats` | `Logic/` (StatsMath, StatsFormat, StatsSnapshot), `Runtime/` SystemSampler, `UI/` (menu bar item, popover, settings) | Core, Platform |
| `FeatureShortcutOverlay` | AX menu walker, overlay | Core, Platform |
| `FeatureTextActions` | Selection reader, action plugins, popup | Core, Platform |
| `FeatureScreenshots` | Capture, editor, pin, OCR, recording | Core, Platform |
| `FeatureFileRules` | Rule engine, FSEvents watcher, undo log | Core, Platform |
| `FeatureUninstaller` | Related-file finder with allowlist | Core, Platform |
| `FeatureArchives` | libarchive wrapper | Core, Platform, `CLibArchive` |
| `CLibArchive` | System-library or binary target for libarchive | none |

Inside each feature module, pure logic (matchers, parsers, rule evaluation, layout math, path filtering) lives in files that import only Foundation, so it can be tested without a window server. AppKit/SwiftUI code lives under a `UI/` subfolder and stays thin.

Settings and onboarding views live in the app target (`App/Settings`, `App/Onboarding`). Their logic (which permissions to ask for, feature state) is in `FeatureRegistry` and is unit-tested there.

## 3. Key types (OmniCore / OmniPlatform)

```swift
/// A user-togglable unit of functionality. Must hold no live resources while disabled.
@MainActor public protocol Feature: AnyObject {
    static var id: FeatureID { get }               // stable string, used as settings key
    var displayName: String { get }
    var summary: String { get }
    var requiredPermissions: Set<Permission> { get }
    var optionalPermissions: Set<Permission> { get } // e.g. microphone for recording
    func enable(context: FeatureContext) throws
    func disable()                                  // must tear down taps, timers, watchers
    func makeSettingsView() -> AnyView
}

public struct FeatureContext {                     // injected services, no singletons
    let hotkeys: HotkeyRegistering
    let permissions: PermissionChecking
    let settings: SettingsStore
    let commands: CommandRegistering
    let log: Log
}

public enum Permission: String, Codable, CaseIterable {
    case accessibility, screenRecording, fullDiskAccess, microphone, appManagement
}

/// Something the palette can show and run. Every feature registers these.
public struct Command: Identifiable, Sendable {
    let id: String; let title: String; let keywords: [String]
    let icon: CommandIcon; let featureID: FeatureID
    let run: @MainActor @Sendable () async -> Void
}

public protocol CommandProvider { func results(for query: String) async -> [Command] } // dynamic results (clipboard, calc)
```

- **FeatureRegistry**: owns feature instances and the persisted "wanted" state. On toggle it checks permissions, calls `enable`/`disable`, unregisters the feature's hotkeys and commands on disable. A wanted feature missing a permission sits in `waitingForPermissions` and starts automatically when the grant appears.
- **Lifetime**: every feature registers teardown for timers, taps, and watchers here. The registry cancels it after `disable()`, so "costs nothing when disabled" holds even if `disable()` misses something.
- **HotkeyManager**: Carbon `RegisterEventHotKey`. Needs no permission and stays reliable. Bindings are stored in `SettingsStore`, rebindable through `HotkeyRecorderView`, with conflict detection.
- **PermissionsManager**: `check(_:) -> PermissionState` (`granted / denied / notDetermined / unknown`), `request(_:)`, `openSettingsPane(for:)` using `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` (and the matching anchors). It polls state only while the onboarding or Settings window is visible.
- **SettingsStore**: typed keys `SettingKey<Value: Codable>` backed by UserDefaults with JSON encoding, `@Observable` so SwiftUI can bind to it.
- **Log**: `os.Logger` per category. Clipboard and selection contents are never interpolated. Helpers only accept lengths and types, and a code review grep check enforces this.
- **FailOpenEventTap**: one wrapper used by every event tap. It handles `tapDisabledByTimeout/UserInput` by **not** re-enabling when it swallows events. It reports to the owner and tears itself down. Callbacks return quickly and never block.

## 4. Permissions per feature

| Feature | Required | Optional / notes |
|---|---|---|
| Palette | none | Network only for the currency fetch |
| Clipboard history | none | Accessibility to paste directly (else copies) |
| Snippets | Accessibility | Listen-only keystroke tap + synthetic ⌘V |
| Window management | Accessibility | Drag-to-edge uses the same permission |
| Window switcher | Accessibility | Screen Recording for thumbnails and other-Space windows (icons without it) |
| Keep awake | none | — |
| Keyboard cleaning | Accessibility | Active event tap |
| System stats | none | — |
| Shortcut overlay | Accessibility | Modifier double-press detection via tap |
| Text selection popup | Accessibility | — |
| Screenshots | Screen Recording | Microphone for recording with mic |
| File rules | none | Full Disk Access if watching protected folders. Desktop/Documents/Downloads get per-folder TCC prompts instead |
| Uninstaller | Full Disk Access | App Management (to trash bundles in /Applications on macOS 13+) |
| Archives | none | — |

Full Disk Access has no query API. Detection is a heuristic: try to read a TCC-protected path such as `~/Library/Safari/Bookmarks.plist`. The result is shown as "likely granted / not granted".

Onboarding shows only the union of `requiredPermissions` for the features the user turned on. It runs again (for the delta) when a feature that needs a new permission is enabled later.

## 5. Phase plans and risks

### Phase 0 — Skeleton
Build: project.yml, package, status item + menu, Settings window (sidebar feature list, toggle, per-feature settings view), HotkeyManager + recorder, PermissionsManager, onboarding, `SMAppService.mainApp` launch-at-login toggle, a `DebugFeature` with a test hotkey that posts a notification/log line.
Tests: SettingsStore round-trip, FeatureRegistry enable/disable lifecycle with a fake feature, hotkey conflict detection, permission-state mapping.
Risks:
- **TCC grants reset when the code signature changes.** Dev builds must be signed with a stable Apple Development identity, not ad-hoc, or Accessibility must be granted again after every build. Needs your Team ID (Q1).
- A SwiftUI `Settings` scene in an LSUIElement app has focus and activation problems, so I'll host SwiftUI in a hand-managed `NSWindow` and switch activation policy while it's open.
- Since macOS 15, `RegisterEventHotKey` rejects shortcuts that use only Option or Option+Shift. The recorder must refuse them and say why.

### Phase 1 — Command palette
Build: a pre-created, hidden non-activating `NSPanel` (shown, not constructed, on hotkey, to meet the <100 ms target). App index from `/Applications`, `/System/Applications`, `~/Applications`, and `/System/Applications/Utilities`, refreshed by FSEvents. Curated System Settings pane list with `x-apple.systempreferences:` URLs. Fuzzy matcher (subsequence scoring with word-boundary/acronym bonuses and a recency boost). Calculator: own recursive-descent parser, not `NSExpression`, which raises uncatchable ObjC exceptions on bad input. Units via Foundation `Measurement`. Currency: ECB daily reference rates XML (no API key), cached to disk with a timestamp, used offline, refreshed at most once a day, with a Settings switch to turn the fetch off.
Tests: matcher ranking fixtures, calculator grammar (precedence, unary minus, %, errors), unit parsing ("5 km in mi"), currency parsing from a fixture XML, stale-cache behavior.
Risks: System Settings panes have no public enumeration API, so the curated list may drift between macOS versions. ECB covers about 30 currencies and no crypto. Latency is measured with signposts, from hotkey to first frame.

### Phase 2 — Clipboard history and snippets
Build: a timer polling `changeCount` at 0.5 s with tolerance, which runs only while enabled. GRDB store in `~/Library/Application Support/Omni/clipboard.sqlite`. Images go to sidecar files plus thumbnails. Search uses FTS5. Pins, retention by count and age. Skip rules: `org.nspasteboard.ConcealedType`, `TransientType`, `AutoGeneratedType`, plus known password-manager bundle ids and the user's exclude list (frontmost app at copy time). Our own writes are tagged with a private marker type so they're ignored. Snippets: an active tap keeps a short rolling buffer of keystrokes (in memory only). On a match it deletes the abbreviation and inserts the expansion through a pasteboard snapshot/restore, then moves the cursor for `{cursor}`. Placeholders: `{date:format}`, `{time}`, `{clipboard}`, `{cursor}`.
Tests: concealed/transient filtering, exclude list, retention pruning, store persistence across reopen, placeholder expansion, abbreviation matcher (word boundaries, backspace handling).
Risks: the frontmost app at copy time is approximate (polling lag). The snippet tap must stay inactive while `IsSecureEventInputEnabled()` is true. Snapshot/restore can't faithfully restore lazy/promised types, so for those we restore only the concrete data types we captured.

### Phase 3 — Window management
Build: an AX frame engine, layout math as pure functions over `visibleFrame` rects, conversion between AppKit (bottom-left) and AX (top-left) coordinate spaces across displays. Order of operations: size, then position, then size again. Then read back. If the app enforced a minimum size, clamp the position so the window stays on the target display. Per-window previous-frame store for restore. Drag-to-edge: a listen-only tap on mouse drag/up with a snap preview overlay.
Tests: layout math for every action on single, side-by-side, stacked, and mixed-resolution display arrangements, coordinate conversion, min-size clamping, next-display cycling.
Risks: some apps animate or resize slowly when `AXEnhancedUserInterface` is on. I'll toggle it off during moves, as established tools do. Identifying the same window across calls needs `_AXUIElementGetWindow`, a **private** API (D2).

### Phase 4 — Window switcher
Build: a window list from `SCShareableContent` (includes off-Space windows), joined to AX windows by CGWindowID. Recency comes from an `AXObserver` per running app (focused-window-changed, plus app activation), seeded by the current front-to-back CGWindowList order. Thumbnails come from `SCScreenshotManager` with a small per-window cache, captured only while the overlay is open. Trigger: an active tap intercepts the chosen modifier+Tab (default Option+Tab; Cmd+Tab possible), with cycling, release to focus, Q/W/Esc.
Tests: the recency ordering model, list merging (minimized, hidden, off-Space, windowless apps), key-state machine.
**Hard limits to accept or decide (D2):**
- Public AX usually returns only windows on the **current Space**. Off-Space windows are visible through SCK but can't be raised directly. With public APIs only, selecting one activates its app, and macOS switches Space only if "switch to a Space with open windows" is on. Fixing this properly needs private CGS/SkyLight calls.
- Minimized windows have no live content. We show the last cached thumbnail or the app icon and un-minimize on select.
- macOS 15+ periodically re-prompts users who grant Screen Recording. We can't suppress that.

### Phase 5 — Utilities
- Keep awake: `IOPMAssertionCreateWithName(PreventUserIdleDisplaySleep)` with a timed or indefinite option. The "while app X runs" option uses `NSWorkspace` launch/terminate notifications (no polling).
- Keyboard cleaning: a full-screen overlay on every display, and a `FailOpenEventTap` swallowing keyDown/keyUp/flagsChanged/NX_SYSDEFINED (media keys). **Fail-open:** if the tap is disabled for any reason, the mode ends immediately. A hard auto-unlock watchdog (default 2 min, configurable). If the process dies, the tap dies with it. Unlock is a mouse click.
- System stats: `host_processor_info` (CPU), `host_statistics64` (memory), `statfs` / `URLResourceValues` (disk), `getifaddrs` byte counters (net), IOKit power sources (battery). A single shared timer runs only while some stat is shown, and the popover refreshes faster only while open.
- **SMC temps/fans: I recommend skipping.** On Apple silicon, temperatures come from private `IOHIDEventSystemClient` sensors or SMC keys whose names differ per chip generation and are undocumented. Results are unreliable across M1–M5 and could break with any OS update. Fans (where present) are slightly more stable, but I'd still leave them out per your rule.
Tests: CPU delta math, network rate math with counter wraparound, timer-state lifecycle, tap-disable → unlock transition (fake tap).
Acceptance check: measure idle CPU with `top`/Instruments with stats off and on, and report the numbers.

### Phase 6 — Shortcut overlay
Build: a listen-only flagsChanged tap feeding a pure state machine (double-press Cmd within ~300 ms, then hold for ≥ ~250 ms). AX walk of `AXMenuBar` → menus → items, reading `AXMenuItemCmdChar`, `AXMenuItemCmdModifiers`, `AXMenuItemCmdVirtualKey`, and `AXMenuItemCmdGlyph`, done off the main thread with a timeout and cached per app plus a menu-change check. Click runs `AXPress`.
Tests: the double-press/hold state machine, modifier mask → glyph string formatting, menu tree flattening/grouping from fixtures.
Risks: Electron and some apps build menus lazily or expose incomplete AX trees. Xcode's menu is large, so the walk needs a cap and a cache. Which Electron app to test: Q5.

### Phase 7 — Text selection popup
Build: a trigger on mouse-up after a drag or double-click (listen-only tap) and on shift+arrow key-up. Read `kAXSelectedTextAttribute` and `kAXBoundsForRangeParameterizedAttribute` from the focused element. Fallback: simulated Cmd+C through `PasteboardSnapshot`, which restores the previous contents only if `changeCount` is still the one we produced. The clipboard history feature ignores our marker type. Guards: skip if the focused element's role or subrole is `AXSecureTextField`, if `IsSecureEventInputEnabled()`, if the app is excluded, or if the selection is empty. Actions follow the `TextAction` protocol (`id`, `title`, `isAvailable(for:)`, `perform(_:)`).
Tests: action availability (URL detection, word count, case transforms), snapshot/restore logic against a fake pasteboard, guard decision table.
Risks: there's no global "selection changed" event. The heuristic will have some false triggers and misses. Many Electron/Chromium apps expose no AX selection, so they always use the Cmd+C fallback. The fallback can't run without disturbing the pasteboard briefly (about 50–150 ms). "Never corrupts" means fully restored afterward and never recorded in history. Lazy/promised types (rare in text copies) can't be restored byte-for-byte.

### Phase 8 — Screenshots
Build: SCK captures, using the display's native pixel scale for each capture so output is pixel-exact. An area that crosses displays is captured per display and composited at the highest scale, with this documented. Editor: Canvas-based layer model (arrow, box, text, blur, highlight, crop, numbered steps) as pure value types and a renderer. Pin as a floating panel. Copy/save PNG. OCR with `VNRecognizeTextRequest`. Recording uses `SCStream` + `AVAssetWriter` (H.264/HEVC MP4). System audio uses `capturesAudio`. Microphone uses `captureMicrophone` on macOS 15+ and a separate `AVCaptureSession` mixed into the writer on macOS 14. Scrolling capture comes last, behind an "Experimental" flag.
Tests: annotation model and transforms, crop/scale math across scale factors, pixel-dimension checks against synthetic images, output file naming.
Risks: the mixed-DPI composite of a cross-display area has no single "correct" pixel grid. Recording mic on macOS 14 needs A/V sync work. Scrolling capture (scroll by synthesized events, stitch by row matching) is inherently fragile.

### Phase 9 — File rules
Build: an FSEvents stream per watched folder (file-level events, latency about 1 s). Engine: `Rule { conditions: [Condition], match: all/any, actions: [Action] }` evaluated against a `FileFacts` snapshot (name, ext, UTType kind, size, dates, `kMDItemWhereFroms` decoded from the xattr binary plist, PDF text via PDFKit with a page cap). Actions plan into `[FileOperation]` first. Dry-run shows the plan, and execution applies it while appending to a JSON-lines undo log. "Delete" only exists as `trashItem`. Name conflicts are resolved by the policy `appendNumber | skip | replaceToTrash`. Loop protection keeps a recently-processed set so the engine doesn't react to its own moves. The shell-script action runs `/bin/zsh -c` with the path in `$1`, a timeout, and no shell interpolation of filenames.
Tests: one or more tests per condition and action, conflict policies, rename pattern tokens, undo of every operation, dry-run equals execution plan, loop protection. Tests run on a temp directory with a fake trash in tests.
Risks: "Date added" relies on `kMDItemDateAdded` (Spotlight) or the `addedToDirectoryDate` resource value, which can be missing on some volumes. Undo can fail if a file was changed in between, and the log records that and reports it. Shell scripts are user code with full user privileges, so Settings warns about that.

### Phase 10 — Uninstaller and archives
- Uninstaller: a hard-coded `SearchRoot` allowlist (`~/Library/{Application Support, Caches, Preferences, Containers, Group Containers, LaunchAgents, Logs, Saved Application State}` and the `/Library/...` equivalents that exist). The matcher only looks at the **direct children** of those roots. Every candidate is canonicalized (`realpath`, symlinks resolved) and must still be inside a root, so it rejects `/System`, other `.app` bundles, and paths with `..` or symlinks escaping the root. Matches are labeled by confidence: exact bundle id/group id = checked by default, name-only = unchecked. Everything goes through `trashItem` and is logged.
- Root-owned items in `/Library` can't be trashed without admin rights. I'll show them as "requires admin, reveal in Finder" rather than build a privileged helper (D5).
- Archives: libarchive read for zip/tar/gz/bz2/xz/7z. Write zip and 7z. Extraction guards against path traversal (`..`, absolute paths, symlinks pointing outside the destination) and against zip bombs (size/ratio cap).
- **RAR: libarchive itself can extract RAR 4 and RAR 5** with its own BSD-licensed, clean-room decoder. No unrar license is involved. Limits: no encrypted RAR and partial multi-volume support. I plan to include RAR extraction on that basis unless you object (Q6).
Tests: allowlist property tests (generated hostile paths, symlinks, `..`, `/System/...`, other bundles never match), bundle-id matching, archive round-trip, traversal rejection, bomb cap.

## 6. Cross-cutting

- **Swift 6 strict concurrency**: AX, CGEventTap, FSEvents, and Carbon callbacks are C callbacks off the main actor. Each wrapper does a minimal hop to `@MainActor` and the payload types are `Sendable`. This is the most likely source of build friction in every phase.
- **Warnings**: `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` in CI config (`make build`), so "fix all warnings" is enforced.
- **Testing command**: `xcodebuild -project Omni.xcodeproj -scheme Omni -destination 'platform=macOS' test`. The scheme includes every OmniKit test target.
- **Network**: two outbound GETs (ECB and NBG rate files). No analytics, crash reporters, or update checks. Sparkle-style updates are out of scope unless you add them.
- **Distribution**: hardened runtime, Developer ID, `notarytool` script. The final notarization run needs your credentials (keychain profile) and happens only when you ask.
- **Per-phase routine**: `make gen build test` → fix warnings → update this file's status table → `git commit` → summary + manual test steps.

## 7. Decisions I need from you

| # | Question | My recommendation |
|---|---|---|
| Q1 | Apple Developer **Team ID** and bundle id prefix (e.g. `com.yourname.omni`)? | Needed so TCC grants survive rebuilds |
| Q2 | Allow **private APIs**? `_AXUIElementGetWindow` (Phases 3–4, very widely used, low risk) and optionally CGS/SkyLight Space APIs (Phase 4 off-Space focus, higher risk). | Allow `_AXUIElementGetWindow`. Skip SkyLight and accept the off-Space limitation |
| Q3 | OK to `brew install xcodegen` on this machine? | Yes |
| Q4 | **libarchive sourcing** (no headers in SDK): (a) build a pinned libarchive release from source into a universal static lib via script, with xz/bz2/zstd static too, or (b) link the system `libarchive.dylib` with vendored matching headers (fragile, undocumented ABI). | (a) |
| Q5 | Which Electron app should Phase 6 be verified against (VS Code, Slack, Discord…)? Is it installed? | VS Code |
| Q6 | RAR extraction via libarchive's built-in BSD decoder (no encryption)? | Include it |
| D5 | Uninstaller: skip root-owned `/Library` items (reveal only) instead of a privileged helper? | Skip; a helper is a large security surface |
| — | SMC temperatures/fans on Apple silicon | Skip (see Phase 5) |

## 8. Status

| Phase | State |
|---|---|
| 0 Skeleton | **done** |
| 1 Palette | **done** |
| 2 Clipboard + snippets | **done** |
| 3 Window management | **done** |
| 4 Window switcher | **done** |
| 5 Utilities | **done** |
| 6 Shortcut overlay | not started |
| 7 Text selection | not started |
| 8 Screenshots | not started |
| 9 File rules | not started |
| 10 Uninstaller + archives | not started |

### Phase 0 — done
- `make build | test | release | run`. Warnings fail the build (`Scripts/check-warnings.sh`). Release is universal (arm64 + x86_64), hardened runtime.
- Menu bar item (LSUIElement, no Dock icon), Settings window (General / Permissions / Shortcuts + one pane per feature with toggle and status dot), onboarding (choose features, then only their permissions), launch at login via `SMAppService`.
- HotkeyManager (Carbon, rebindable, conflict + OS-refusal detection, persisted), PermissionsManager (state, prompt, deep link, polling only while a window is open), SettingsStore, Log, CommandRegistry, FeatureRegistry, Lifetime.
- Diagnostics feature: ⌃⌥⌘T shows a "Test hotkey fired" HUD and counts presses.
- 46 unit tests (Swift Testing), all passing via `xcodebuild test`.

### Phase 0 — deferred
- Real signing: waiting for an Apple Development certificate (then Developer ID for notarization). `Scripts/notarize.sh` comes with the first release.
- Layout-aware key names in shortcuts (AZERTY etc.). Key codes are layout-independent, but labels assume ANSI.
- Stopping a running feature when its permission is revoked mid-session. Today it only blocks the next start.
- An automated hotkey press test. Synthesizing keystrokes needs Accessibility for the test runner, so it's a manual check.

### Phase 1 — done
- Palette: ⌃⌥Space (rebindable) opens a pre-built non-activating panel on the screen with the mouse. The frontmost app keeps focus. Esc/click-away closes.
- Keyboard: type to search, ↑/↓ or ⌃N/⌃P, Page Up/Down, ↩ runs, ⌘↩ reveals an app in Finder.
- Sources: installed apps (`/Applications`, `/System/Applications`, `~/Applications`, CoreServices apps, Finder; rescanned by FSEvents), System Settings panes (curated titles filtered to extensions installed on this macOS, plus Privacy sub-lists), and every enabled feature's commands plus app commands (Settings, Setup Guide, Quit).
- Ranking: fuzzy subsequence matching with prefix, word-start, camelCase, and consecutive bonuses. Keywords count less than titles. Usage boost with a 14-day half-life, and the empty query shows recent items.
- Quick answers: calculator (own parser: + − × ÷ ^ % mod, functions, constants), units (length, mass, temperature, volume, area, speed, duration, data), currency (ECB rates, cached in Application Support, refreshed at most every 6 h on palette open, 15-min backoff on failure, works offline from the cache). ↩ copies the number.
- `omni://palette` opens the palette (only that action; links can't run other commands).
- Open time, measured from command dispatch to the panel drawn: 30 ms cold, 2.6–4.3 ms warm (log category `palette`; also shown in Settings).
- 54 new tests (100 total).

### Phase 1 — deferred / limits
- ~~GEL missing~~ Added: National Bank of Georgia feed (`nbg.gov.ge/gw/api/ct/monetarypolicy/currencies/en/json`) as a second source with the same caching and backoff rules. GEL pairs use NBG's official rates; other pairs prefer the ECB, and NBG covers what the ECB lacks (e.g. AMD, AZN, KZT, UAH). If NBG is unreachable and nothing is cached, GEL shows "rate not available" and everything else keeps working. Network endpoints are now exactly two GETs, ECB and NBG.
- Dynamic palette providers (clipboard history search) arrive with Phase 2. Today commands are static per feature.
- Settings pane titles are English only. macOS ships no public localized names for them.
- Hotkey-to-screen latency isn't measured end to end (Carbon delivery is outside our clock). The figure above starts when the hotkey handler runs.

### Phase 2 — done
- **Palette providers** (`SearchProvider` in OmniCore): `clip …` / `snip …` scope the palette to one feature; other queries mix in each provider's top 3 after the top 5 ranked items. Features can open the palette prefilled (`openPalette(query:)`).
- **Clipboard History** (on by default, no permission):
  - Capture: polls `changeCount` every 0.5 s (timer exists only while enabled).
  - What's skipped: the policy runs on the type list *before* reading content and rejects concealed (plus legacy 1Password/KeeWeb markers), transient, auto-generated, Omni-internal, built-in password-manager apps, and the user's exclude list.
  - What's kept: files beat their names, then images (PNG + 96 px thumbnail via ImageIO), then text. Limits are 2 MB of text and 25 MB per image.
  - Store: GRDB at `~/Library/Application Support/com.george.omni/clipboard` (folder mode 0700), FTS5 prefix search, de-duplicated by SHA-256 (a repeat copy moves to the top), pin, delete, clear.
  - Retention: count (default 500) + age (default 30 days); pinned items are exempt.
  - Palette: ↩ pastes (Accessibility) or copies; ⌘↩ copies. ⌃⌥V opens `clip `. Settings has a history browser and the exclude list.
- **Snippets** (requires Accessibility):
  - Listening: listen-only `EventTap`, so it can't block keys. The buffer is in memory only, and it stops while secure input is on.
  - Matching: abbreviations need a word boundary unless they start with punctuation; the longest match wins.
  - Expansion: backspaces, then a ⌘V paste via `TemporaryPasteboard` (transient + internal marker), and the previous pasteboard is restored after 400 ms if unchanged. Placeholders are `{date[:fmt]}`, `{time[:fmt]}`, `{clipboard}`, `{cursor}`, `{{`/`}}`.
  - Also insertable from the palette.
- **Fail-open `EventTap`**: listen-only taps re-enable after a system timeout. Filtering taps (Phase 5) stop and report instead of re-enabling.
- **GRDB vendored** (`Vendor/README.md`: source URL, SHA-256, upgrade steps). It emits 2 Swift 6.2 Sendable warnings, which the gate lists but doesn't fail on.
- **Acceptance checks** — automated tests and in the running app:
  - History survives restart (store reopen test, plus a real app restart).
  - Concealed items are never stored (`ClipboardMonitorTests` against a private pasteboard, plus a real concealed copy in the running app that didn't appear).
- 62 new tests (162 total).

### Phase 2 — deferred / limits
- Rich text (RTF/HTML) isn't kept; text entries store plain text only.
- The source app is the frontmost app at poll time (up to 0.5 s late), so a copy made right before switching apps can be attributed to the wrong app.
- `{cursor}` moves the caret with ← presses. Apps that treat ← specially (some terminals) may misplace it.
- Snippet restore can't bring back lazily promised pasteboard data byte-for-byte. Plain text, RTF, images, and file URLs restore exactly.
- Pin/unpin from the palette itself (e.g. ⌘P) isn't implemented; pinning is in Settings.
- The history database isn't encrypted at rest; it relies on the 0700 folder and FileVault.

### Phase 3 — done
- **Actions:**
  - Layouts: halves, thirds, two-thirds, quarters, maximize, center.
  - Moves: next/previous display (keeps the relative frame, clamped to fit).
  - Restore: back to the frame from before Omni first moved the window. A manual move resets this.
  - Gaps: optional, 0–24 pt.
  - Every action has a ⌃⌥ shortcut (display moves ⌃⌥⌘←/→, restore ⌃⌥⌫, maximize ⌃⌥↩) and a palette command.
- **Geometry**: all math is in AX coordinates (top-left of the primary display, y down). `ScreenGeometry` converts from AppKit and picks the display with the most overlap. Display order is left to right, then top to bottom.
- **Minimum sizes**: set size → position → size, then read back. If the app kept a different size (minimum or character-cell steps), the window is re-anchored to the action's edge (right half keeps the right edge, bottom quarter the bottom edge, center stays centered) and clamped onto the display.
- **`AXEnhancedUserInterface`** is turned off around each move and restored afterwards, which prevents slow, animated moves in apps that enable it. AX calls use a 0.5 s messaging timeout.
- **Drag-to-edge** (off by default): a listen-only tap on left-mouse events that only reacts when the drag starts in the top 40 pt of a standard, resizable window. A translucent preview shows the target. Edges snap to halves, corners to quarters, the top edge maximizes, and edges shared with another display don't snap. A window that didn't move (a click) isn't snapped.
- **Fails gracefully**: full-screen windows, windows that can't be read, nothing to restore, or only one display connected each show a HUD and change nothing.
- 30 new tests (192 total), including multi-display fixtures (side by side with different heights, stacked above with negative AX y, a display to the left at negative x) and min-size anchoring.
- `make run` retries `open` once. One unexplained failure happened and didn't reproduce in four later runs.

### Phase 3 — deferred / limits
- External monitor: not tested on hardware (the user's confirmation left it open; only the built-in display was connected during development).
- Verified on one built-in display only. Multi-display behavior is covered by unit tests with real-world arrangements, but not yet on hardware.
- Repeating an action doesn't cycle sizes (e.g. ½ → ⅔ → ⅓, as some tools do).
- Windows without a CGWindowID (rare) can be arranged but not restored.
- Drag-to-edge uses the window under the pointer at mouse-down. Apps that draw custom title bars taller than 40 pt (some Electron apps) only snap when grabbed near the top.

### Phase 4 — done
- **Trigger**: ⌥Tab by default (⌘Tab or ⌃Tab selectable). A filtering `EventTap` swallows only Tab while the modifier is held, and the switcher's keys while it's open. Any other key closes the switcher and passes through. If the modifier is already released by the time the switcher opens, it switches at once. If macOS disables the tap, the switcher pauses (fails open) and says so.
- **Keys**: Tab / ⇧Tab cycle (wrap), arrows move, releasing the modifier or ↩ switches, Esc cancels, Q quits the selected app, W presses the window's close button (the app may still ask to save). Clicking a tile switches. The overlay appears after 120 ms, so quick taps switch without a flash.
- **List**: window server (front-to-back, `.optionAll`) merged with Accessibility windows of each regular app. Only standard windows ≥ 80×50 on layer 0 are kept, with Omni excluded. States are normal / minimized / hidden app / other Space. Windows not reachable through Accessibility are kept only with a real title and ≥ 200×120 (so offscreen helper windows stay out); without Screen Recording they have no title, so other-Space windows aren't listed.
- **Recency**: one `AXObserver` per app (focused/main window changed), plus app-activation notifications, and the focused window is touched again when the switcher opens. Order: recently focused → never-focused in stacking order → minimized → hidden.
- **Focus**: un-hide the app if hidden, un-minimize, set the app frontmost, set the window main, raise. Other-Space windows activate their app (the accepted limit).
- **Thumbnails**: ScreenCaptureKit `SCScreenshotManager` per window (≤ 400 pt, up to 24), captured only while open. The last image is kept for windows that can't be captured (minimized), with the app icon otherwise.
- **Palette**: `win …` searches open windows; "Switch to Window…" command.
- 19 new tests (211 total).

### Phase 4 — deferred / limits
- Thumbnails are captured once per opening, not streamed continuously; the window under the overlay doesn't update while it stays open.
- Apps with no open windows aren't listed (use the palette to launch or activate them).
- Off by default; requires Accessibility, and Screen Recording for previews. macOS 15+ periodically asks the user to reconfirm Screen Recording.
- Q and W use key positions (QWERTY), not characters.

### Phase 5 — done
- **Keep Awake** (on by default, no permission): one IOKit assertion (`PreventUserIdleDisplaySleep`, or `…SystemSleep` if "keep display on" is off).
  - Manual session: indefinite or timed (15 min–5 h), not persisted across restarts. A single one-shot timer handles the end time.
  - "While these apps run" rules (persisted): launch/quit observers exist only while rules exist.
  - Control: palette commands, ⌃⌥⌘A toggle, Settings.
  - Unit test checks the assertion through `IOPMCopyAssertionsByProcess`: visible while held, gone after release.
- **Keyboard Cleaning** (Accessibility): ⌃⌥⌘L, the palette, or Settings.
  - Start: begins after 0.7 s, so you can release the shortcut.
  - Blocking: a filtering tap swallows keyDown/keyUp/flagsChanged/NX_SYSDEFINED (media and brightness keys). A full-screen non-activating overlay on every display has a mouse-only Unlock button and a countdown.
  - **Fail open**: tap disabled by macOS → session ends at once (no re-enable, tested). A hard watchdog ends it at the time limit (default 2 min, capped at 10). If Omni exits, the tap goes with it. Unlocking stops the tap before anything else.
  - Can't block the power button or Touch ID (system level).
- **System Stats** (off by default):
  - Readings: CPU (host_processor_info deltas), memory (Activity Monitor formula: app + wired + compressed), startup disk free (read every 60 s), network throughput (getifaddrs, physical links, 32-bit wrap handled), battery (IOPS).
  - Menu bar: separate item with selectable text items; icon only if none are selected; fixed width so neighbors don't shift. Detail popover with gauges.
  - Refresh: one timer (1/2/5 s, default 5 s after the measurements below; 25% tolerance).
  - **Temperatures and fans skipped**: on Apple silicon they're only readable through undocumented, chip-specific SMC/HID keys.
- **Idle CPU measurements** (60 s, `ps` CPU time plus `top`, after warm-up):
  - Without System Stats (your feature set): 0.05–0.20%, 0–14 wakeups/s (mostly the 0.5 s clipboard poll).
  - System Stats, icon only, 2 s: 0.20%. Sampling itself is negligible.
  - System Stats, CPU + MEM + network text, 2 s: 1.67%; at 5 s: 0.68%.
  - The text cost is AppKit's, not Omni's: each title change runs `NSStatusItem _updateReplicants`, re-rendering bitmap snapshots of the item (~30 ms per change on this macOS). It only happens at refresh ticks; there's no other background work.
- 22 new tests (234 total).

### Phase 5 — deferred / limits
- No menu bar indicator for Keep Awake beyond HUD and Settings. Status items are per-feature and Keep Awake doesn't add one.
- Disk shows free space on the startup volume, not I/O throughput.
- Stats text redraw cost (above) could be reduced only by updating less often; a custom-drawn view still goes through the same replicant path.
