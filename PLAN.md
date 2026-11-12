# Omni — Implementation Plan

Status: **approved. Phases 0–8 and Interface and onboarding done; next: Ask AI in the Launcher (planned below, waiting for approval)** (see §8 and DESIGN.md).

## 0. Environment found

| Item | State |
|---|---|
| Xcode | 26.1 (17B55), Swift 6.2.1 |
| Host OS | macOS 27.0.1, arm64 |
| XcodeGen | 2.46.0 via Homebrew (build tool only) |
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
| `FeatureShortcutOverlay` | `Logic/` (HoldGesture, ShortcutFormatter, MenuModel: ShortcutCatalog + ColumnPacker), `Runtime/` (MenuReader + MenuCache, ModifierTap), `UI/` (OverlayController, OverlayView, ShortcutOverlayFeature) | Core, Platform |
| `FeatureTextActions` | `Logic/` (TextSelection, TextAnalysis + SearchEngine, SelectionGuard, SelectionTrigger, CopyFallback), `Actions/` (TextAction protocol + built-ins), `Runtime/` (SelectionReader, SelectionTap), `UI/` (PopupController, PopupView, TextActionsFeature) | Core, Platform |
| `FeatureScreenshots` | `Logic/` (CaptureGeometry, FileNaming, Annotation + AnnotationDocument, AnnotationRenderer, AlphaBounds, ScrollStitcher, TextRecognizer), `Runtime/` (ScreenCapturer + CaptureOutput, ScreenRecorder, ScrollingCapture), `UI/` (SelectionOverlay, EditorModel/EditorView, CaptureWindows + pin, RecordingController, ScreenshotsFeature) | Core, Platform |

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
    case accessibility, screenRecording, microphone
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
| Q5 | Which Electron app should Phase 6 be verified against (VS Code, Slack, Discord…)? Is it installed? | VS Code |
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
| 6 Shortcut overlay | **done** |
| 7 Text selection | **done** |
| 8 Screenshots | **done** |
| Interface and onboarding | **done** |
| Ask AI in the Launcher | planned (§9), waiting for approval |

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

### Phase 6 — done
- **Shortcut Overlay** (Accessibility, off by default): shows the frontmost app's menu shortcuts, one section per menu, submenu items as "Find › Find Next", disabled items dimmed (optional). Click an item to run it (`AXPress`, off the main thread; `cannotComplete` from items that open a sheet isn't reported as a failure).
- Triggers:
  - Hold mode: press ⌘ twice and keep holding (tap ≤ 300 ms, gap ≤ 300 ms, hold 250 ms). The overlay stays while the key is held; release, any key, or switching apps hides it. ⌥ or ⌃ can be chosen instead, or Off.
  - Pinned mode: ⌃⌥⌘/ (rebindable) or the palette command "Show Keyboard Shortcuts". It has a filter field; ↩ runs the first match, Esc or clicking elsewhere closes it.
- Input: a **listen-only** tap (flagsChanged, keyDown, mouse down) feeds a pure state machine. It can't block anything. Keys only cancel the gesture and are never stored or logged. With the trigger set to Off, no tap runs.
- Menu reading: AX walk of `AXMenuBar` on a background task (Apple menu skipped), batched attribute reads, limits of 4000 items, depth 4 and 3 s. Per-element messaging timeout 0.25 s, with 1 s for the first call, which may wake an app from App Nap. Reading starts at the second press, so it's usually ready before the hold completes. The cache (6 apps) shows the last copy at once and refreshes in the background; reads within 2 s are reused.
- Shortcut formatting: AX modifier bits (⇧ ⌥ ⌃, no-⌘, and bit 0x10 = fn/🌐, found in Finder's "Emoji & Symbols"), Carbon menu glyphs, AppKit function-key characters, and virtual-key fallback.
- Measured reads (first / repeat):
  - Cursor (Electron; VS Code isn't installed): 351 items, 115 shortcuts, 79 / 15–100 ms. Cursor rebuilds its menu per window type, and the agents window has fewer items (99).
  - Finder: 250 items, 113 shortcuts, 86–192 / 16–21 ms.
  - Safari: 482 items, 103 shortcuts, 240 / 37 ms.
  - Xcode: 840 items, 264 shortcuts, 961 / 61–91 ms.
- Idle CPU with the overlay on: 0.05% (60 s).
- `make run`: LaunchServices can return -600 yet still launch the app. The retry now runs only if Omni isn't running; before, it counted as a re-open and showed Settings.
- 20 new tests (254 total).

### Phase 6 — deferred / limits
- Only menu-bar shortcuts can be listed. Shortcuts that exist only inside a window, a web view or an editor keymap (e.g. most of VS Code's editor bindings) aren't in the menus, so they can't be shown.
- Alternate items that appear only while ⌥ is held aren't exposed by Accessibility, so they're missing.
- Menus an app builds only when opened (some Electron menus) show what's there at read time.
- No palette provider for menu items yet ("keys …" search). The pinned overlay's filter covers it.

### Phase 7 — done
- **Text Selection Popup** (Accessibility, **off by default**): after a selection, a small bar appears above it. Actions:
  - Copy, Paste, Open Link (web URLs only), Search the Web (Google, DuckDuckGo, Bing or Kagi).
  - Translate (Apple's translation panel, macOS 14.4+, can replace editable text).
  - UPPERCASE and lowercase (editable text only), Word Count (HUD), Send to Palette.
  - Each action can be turned off. Actions implement `TextAction` (`id`, `title`, `symbolName`, `isAvailable(for:)`, `perform(_:context:)`).
- Trigger (heuristic, listen-only tap): mouse drag ≥ 6 pt, double/triple click, ⇧-click, or ⇧+arrow/Home/End/Page keys. Checks run 120 ms after the mouse-up and 350 ms after the key-up.
  - The bar closes on typing, scrolling, a click elsewhere, switching apps, or after 8 s without the pointer on it.
  - Key events are only classified, never read, stored, or logged.
- Reading, Accessibility first:
  - The focused element's `AXSelectedText`, bounds via `AXBoundsForRange`, editability via settable `AXSelectedText`. Read on a background task with 0.3 s timeouts.
  - Selections over 100,000 characters are ignored, never truncated.
  - Replacing uses `AXSelectedText` when possible, else a ⌘V of a temporary, history-ignored pasteboard that is restored afterwards.
- ⌘C fallback (on by default, can be turned off):
  - Used only when Accessibility has no selection attribute: most Electron/Chromium apps.
  - Mouse gestures must lie inside the window's content area, not the title bar or edges.
  - Not used if a mouse button or modifier is held, if secure input started, or in Finder.
  - Restores the previous pasteboard unless something else wrote it meanwhile. Concealed content is discarded and restored; files and images don't count as text.
  - `PasteboardLease` pauses clipboard history during the borrow (expires after 2 s at most). The restored copy carries Omni's marker, so neither the selection nor the restore is recorded. There's a test for this in `ClipboardMonitorTests`.
- Password safety (decision-table test):
  - Skipped while `IsSecureEventInputEnabled()`, for `AXSecureTextField` role or subrole (checked before the text is read), and in password managers (shared list `KnownApps.passwordManagers`, now also used by clipboard history).
  - Also skipped in user-excluded apps and in Omni itself.
- Live check (TextEdit scratch document, background, via the real reader):
  - Read "world": role AXTextArea, editable, bounds (244.7, 124, 33.1, 13).
  - AX replace → "Hello WORLD …".
  - Popup rendered off-screen.
  - The ⌘C fallback was tested with a fake pasteboard only; a live test would send ⌘C to the app in use.
- Idle CPU with the feature on: 0.2% over 60 s, including the clipboard poll.
- 27 new tests (281 total). One of them caught a race: a copy made right after the app's own ⌘C answer could be mistaken for the selection and then overwritten. Fixed.

### Phase 7 — deferred / limits
- Heuristic trigger: no system "selection changed" event exists. Selections made by ⌘A, Find, or programmatically don't show the bar. Drags that aren't text selections can show it when the app reports a selection.
- Electron/Chromium: the ⌘C fallback borrows the pasteboard for about 10–300 ms. Other clipboard managers polling in that window could see the selection. Omni's history never does.
- Restore re-writes data, so types an app only promised (lazy data) are materialized, and the restored item carries Omni's marker type.
- Translate is Apple's panel; whether it runs on-device depends on the system's Translation settings. Search and Open Link hand the text to the browser only when clicked.
- The bar is placed at the mouse-up point when the app doesn't report selection bounds (all fallback reads).

### Phase 8 — done
- **Screenshots** (Screen Recording; optional Microphone and Accessibility; off by default). It does no background work; it only registers hotkeys.
- Shortcuts, all rebindable:
  - ⌃⌥⌘4: area or window. Drag an area or click a window, with the hovered window highlighted.
  - ⌃⌥⌘3: the screen under the pointer.
  - ⌃⌥⌘O: capture text (OCR).
  - ⌃⌥⌘R: start or stop recording.
  - Scrolling capture: Experimental, off, no default shortcut.
  - Palette commands exist for each.
- Overlay: one panel per display at `.screenSaver` level, dimmed, showing a live pixel-size label and a hint. Esc or right-click cancels. The overlay is removed and given 120 ms before capturing.
- Pixel correctness:
  - Each display is captured at its native scale (`CaptureGeometry.plan`, snapped to the pixel grid).
  - Areas across displays are composited at the highest scale, with the lower-scale part enlarged nearest-neighbour.
  - PNGs are saved at 72 × scale dpi (144 on Retina).
  - Live checks on the Retina display:
    - A 100.5 × 24 pt area gave 201 × 48 px.
    - Full screen: 3600 × 2338 px.
    - A 100 × 24 pt area was **byte-identical to `screencapture -R`** (0 of 38,400 bytes differ, both Display P3, 144 dpi).
- Window capture: `SCContentFilter(desktopIndependentWindow:)` at `pointPixelScale`.
  - With shadow: the window is rendered unscaled on a canvas 150 pt larger on each side, then trimmed to the visible pixels (`AlphaBounds`).
  - The shadow was missing at first: asking for the window's own size made ScreenCaptureKit shrink the window to fit its shadow, which was found live and fixed.
  - Verified: 1958 × 2214 px with shadow, and the window inside exactly 1734 × 1990 (1:1).
- After capture (setting): open the editor (default), copy, save, or pin. The save folder defaults to macOS's screenshot location (`com.apple.screencapture location`, else Desktop). Names look like "Screenshot 2026-11-12 at 17.20.31.png", with "(2)" etc. on collisions.
- Editor:
  - Tools: select/move, arrow, box, text (click to type, click existing text to edit), highlight, blur (pixelate + blur, so text can't be recovered), numbered steps (renumber on delete), crop. Seven colours, single-letter tool keys, ⌘Z / ⇧⌘Z, Delete.
  - Copy (⌘C), Save (⌘S), Pin, Copy Text (OCR).
  - The preview and the export share one CoreGraphics renderer. With no marks the export returns the original image (bit-exact, tested).
- Pin: floating, movable, resizable with aspect kept, on all Spaces. Its menu has Copy, Save, Edit…, Opacity and Close; Esc also closes it.
- OCR: Vision `VNRecognizeTextRequest` (accurate, automatic language), on device. Lines are ordered top to bottom; the text is copied to the clipboard.
- Recording:
  - `SCStream` → `AVAssetWriter` MP4, H.264 (default) or HEVC, 30 or 60 fps, pointer optional. Even pixel dimensions; one display per recording.
  - Omni's own windows are excluded. A ● m:ss menu bar item stops it, as does the shortcut. The file is revealed in Finder.
  - System audio (`capturesAudio`, excluding Omni's own) and the microphone (macOS 15+ `captureMicrophone`) go to separate AAC tracks.
  - Verified: a 3.1 s recording at 802 × 602 (401 × 301 pt area, made even), H.264 at about 30 fps, plus an AAC system-audio track.
- Scrolling capture (Experimental flag): scrolls the area with posted scroll events, captures each page, and joins them by row fingerprints.
  - Fixed headers and footers are detected and kept once. Blank rows don't count as matches.
  - Stops at the end of the content, if no overlap is found, on Esc, at 30 pages, or at 30,000 px.
- 25 new tests (306 total): mixed-DPI plans, snapping, even recording sizes, file naming, bit-exact and crop rendering, marks only changing their area, step renumbering, hit testing, arrowheads, stitching (plain, header/footer, end, no overlap, blank rows, real image round trip), alpha bounds, and OCR of rendered text.

### Phase 8 — deferred / limits
- Mixed-DPI and external displays were tested by math only (no second display here).
- Microphone on macOS 14 is not supported (it needs macOS 15's ScreenCaptureKit microphone). The plan's separate `AVCaptureSession` path was left out because it couldn't be tested on this Mac. The setting says "macOS 15 or later".
- System audio and the microphone are two tracks, not mixed. QuickTime plays both; some players play only the first.
- A recording covers one display; an area across displays records the part on the display holding its centre.
- The first OCR after installing a new build can take about a minute while macOS prepares the text model (measured: 58–70 s once, then 0.06–0.2 s). A "Recognizing text…" notice shows meanwhile.
- Scrolling capture moves the pointer to the area during the capture and restores it afterwards. It was tested on synthetic pages only, not live (that would scroll a window in use).
- No "capture the same area again", no delayed/timer capture, and no editor zoom beyond fit-to-window.

### Interface and onboarding — done
Design: DESIGN.md (approved). UI only; feature behaviour unchanged except where noted below.
- **Menu bar:**
  - The main icon opens the control panel on left-click and a short menu on right-click.
  - Quick-access icons are on by default for Keep Awake (filled cup while on), Screenshot and Clipboard; Screen Recording, Lock Keyboard and Window Layouts are optional. Left-click runs the main action, right-click shows the feature's options (built from each feature's `quickAccessItems`).
  - Settings → Menu Bar chooses icons, reorders them, or switches to one-icon mode (which also hides System Stats' own item). The recording timer shows on the Record icon or on the main icon.
  - Icons use positional slots (`omni.slot.r<n>`, counted from the main icon) because macOS 27 keeps icon positions in a system store apps can't change. Reordering refills slots; checked live for 3 and 4 icons in two orders.
- **Control panel** (⌃⌥⌘M, the main icon, `omni://panel`): a non-activating panel, so the app you were using stays active.
  - Contents: five tiles with shortcuts and states (on, off with a "Turn On" prompt, needs permission, recording), the 3 latest copies (click or 1–3 pastes), a layout grid for the frontmost window, the stats line, Settings and Quit.
  - Keyboard: arrows, ↩/Space, ⇧↩ for options, Esc. Checked live.
- **Onboarding:** 4 screens:
  - What Omni does.
  - Choose features (Recommended / Everything / None); choices apply on Continue.
  - Permissions for the chosen features only, with live status and Skip.
  - Shortcut cheat sheet with "Try It".
- **Settings:**
  - Overview cards with switch, status and shortcut.
  - A permission banner on feature pages.
  - Search across every setting, which scrolls to and highlights the setting.
  - One shortcuts table with conflict warnings, including features that are off; rebinding works while a feature is off.
  - Per-feature Reset to Defaults (keeps on/off and user content) and Erase Data… (separate, red, confirmed).
  - Reset All Settings.
  - Diagnostics is hidden unless ⌥ is held while Settings opens. It's off by default for new users; existing users keep their state (migration).
- **Strings:** all user-facing text is in `OmniCore/Resources/Localizable.xcstrings` (611 keys, English) through `L10n` accessors.
  - `Scripts/gen-strings.py` rebuilds the catalog.
  - `Scripts/check-strings.sh`, part of `make build`/`make test`, fails on UI literals outside `L10n` or on a stale catalog.
- **Consistency:** shared components in `OmniPlatform/OmniUI.swift` (ShortcutChip, StatusBadge, EmptyState, SectionHeader, panel background, settings anchors). Reduce Motion turns off fades and slides; Increase Contrast adds borders. Empty states as listed in DESIGN §5.2.
- **Removed:** the Full Disk Access and App Management permission kinds and the Full Disk Access probe. Two registry tests now use Screen Recording and Microphone; the Full Disk Access heuristic test was deleted with its code.
- **Tests:** 332 total. 27 are new: MenuBarConfiguration, SettingsIndex, SettingsReset, ShortcutTable, OnboardingModel, ControlPanelFocus, L10n catalog, and rebinding a shortcut while its feature is off.

### Interface and onboarding — deferred / limits
- A feature's settings aren't shown dimmed while it's off; the page says "Turn on … to see and change its settings." (The settings views need the feature's running store.)
- Keep Awake's menu has no "While Certain Apps Run…" item; its Settings page covers it.
- The Launcher's "Press ↩ to search the web" empty-state hint was left out, because it would be new behaviour.
- Clipboard: deleting history (Clear, Erase, retention, single delete) removes image and thumbnail files directly, not through the Trash. This predates this phase and conflicts with the "destructive file operations go to Trash" rule; it needs a decision.
- With no search text, the Launcher's clipboard list is now newest first, including pinned items (needed for the control panel's "recent").
- Not localized (left as data): macOS System Settings pane names, bank and search engine brand names, and unit abbreviations.
- Not added: a fixture test for `check-strings.sh` and per-feature menu-content tests (the menus need running features).
- The language picker shows English only.

## 9. Phase plan: Ask AI in the Launcher (on-device only)

### What the framework offers (checked 2026-11-12)
Sources: the FoundationModels interface in the installed SDK (MacOSX 27.2, Xcode 26.1 toolchain; this Mac runs macOS 27.0.1 on Apple silicon) and Apple's documentation (`developer.apple.com/documentation/foundationmodels`: SystemLanguageModel, Availability, LanguageModelSession, streamResponse, GenerationError, LanguageModelError, the "Generating content…" article).
- **Model:** `SystemLanguageModel.default` is "an on-device Apple Foundation Model", available since macOS 26; Apple lists it as working offline.
  - The framework also has `PrivateCloudComputeLanguageModel`, a cloud model (macOS 27, entitlement-gated, daily quota).
  - **Omni never references it.** A unit test checks this by searching the module's source for the type name.
- **Availability:** `.available`, or `.unavailable(.deviceNotEligible | .appleIntelligenceNotEnabled | .modelNotReady)`.
  - `modelNotReady` covers the model still downloading.
  - The model object is Observable, so its availability can change while Omni runs.
  - Below macOS 26 the framework doesn't exist, so Omni reports "needs macOS 26".
- **Sessions:**
  - A `LanguageModelSession` keeps the conversation (its transcript) across calls and handles one request at a time (`isResponding`).
  - `streamResponse(to:)` yields snapshots of the answer so far.
  - The context limit is 4,096 tokens for instructions, prompts and answers together. Going over it throws `contextSizeExceeded`.
- **Errors:** macOS 26 throws `LanguageModelSession.GenerationError`; macOS 27 throws `LanguageModelError` and related types.
  - Cases include refusal, guardrail violation, unsupported language or locale, context too large, rate limited, and assets unavailable.
  - Both families are mapped to Omni's own small set (see Engine).
- **Strengths:** Apple notes the on-device model is weak at math, code and logical reasoning. The Launcher's calculator keeps handling math.

### Design
- **New module `OmniAI`** (depends on OmniCore only). The Launcher (FeaturePalette) depends on it, just as features use OmniPlatform.
  - `AnswerEngine` protocol: `availability`, `newConversation(instructions:)`. `AnswerConversation`: `stream(prompt) -> AsyncThrowingStream<String, Error>` (text so far).
  - The only implementation is `SystemModelEngine` (FoundationModels, inside `#if canImport(FoundationModels)` and `if #available(macOS 26, *)`).
  - FoundationModels is **weak-linked** (`-weak_framework FoundationModels`) so Omni still launches on macOS 14 and 15. `otool -l` will be checked to confirm.
  - No other provider, no network code, no API keys.
- **`AskSession`** (OmniAI, @MainActor, pure enough to test with a fake engine):
  - Holds the turns (question, attachment, answer, state).
  - States: idle, answering, answered, stopped (Esc, partial text kept), failed(kind).
  - Operations:
    - `ask(question, attachment)` runs one answer at a time.
    - `cancel()` cancels the task.
    - `reset()` drops the conversation and turns.
    - A context overflow starts a fresh conversation with a one-line notice ("Started over: the conversation got too long").
- **Error kinds Omni maps to:** `cantAnswer` (refusal, guardrail, empty answer), `unsupportedLanguage`, `unavailable` (assets missing or the model became unavailable), `busy` (rate limited), `other`.
  - `cantAnswer` and `unsupportedLanguage` offer **"Search the web for “…”"**.
  - The others show one plain sentence.
- **Instructions to the model:** be brief and plain; if unsure, or if the question needs current information, say so instead of guessing. The maximum answer length stays at the framework default unless testing shows rambling.
- **Launcher trigger:**
  - **Tab** on any non-empty query asks it, and a query starting with **"?"** switches to Ask mode as you type ("? how do I …").
  - When Ask is unavailable, Tab and "?" behave exactly as today (Tab does nothing; "?" is ordinary text).
- **Ask mode panel:** the results list is replaced by the conversation:
  - Your question, then the answer streaming in as selectable text, with a spinner while it runs.
  - Attachment chips with ✕.
  - A notice under the answers: "Answered on this Mac by Apple's model. It can be wrong and doesn't know about recent events."
  - A hint line: "↩ Copy · ⌘↩ Paste · Tab Ask · Esc Stop".
- **Keys in Ask mode** (needs your OK, Q1):

  | Key | Action |
  |---|---|
  | Tab, or ↩ while a follow-up is typed | Asks the follow-up in the same conversation |
  | ↩ with an empty field | Copies the latest answer and closes |
  | ⌘↩ | Pastes the latest answer into the app that was active before the Launcher, then closes. Uses the existing temporary-pasteboard ⌘V, so your clipboard is restored |
  | Esc while answering | Stops the answer; partial text kept, marked "Stopped" |
  | Esc otherwise | Closes the Launcher, as today |

- **Context:** follow-ups stay in one session until the Launcher closes. Closing (Esc, click away, running a result) calls `reset()`, so the next question starts fresh. Nothing is kept in memory after closing or written to disk.
- **Attachments** (explicit only; never automatic):
  - "Attach Clipboard" (⌘⇧V, also a button) adds the clipboard's plain text.
    - It's refused when the clipboard holds password-manager or concealed content, or isn't text.
  - "Attach Selection" (⌘⇧S, also a button) adds the text selected in the previously active app.
    - It reads through Accessibility only; Ask won't briefly copy the selection.
    - It's skipped in password fields, while secure input is on, and in password managers.
    - The Accessibility reader moves from Text Actions to OmniPlatform so both use it; Text Actions' behaviour is unchanged.
  - **Size limit:** about 6,000 characters per attachment, because of the 4,096-token context. A longer attachment is refused with "too long to attach" (Q3).
- **Privacy:**
  - Only the typed question plus any attachment you added goes to the model.
  - Questions and answers never appear in logs (only kinds, counts, durations and error kinds) and aren't added to Launcher usage history.
  - The on-device model makes no network call. Omni's only network use stays the two currency feeds.
- **Availability UI:**
  - Ask is hidden completely when unavailable: no Tab or "?" mode, no hints.
  - Availability is checked each time the Launcher opens (no polling).
  - Settings → Launcher shows one line, with a button where it helps:
    - Available: "Ask is ready: press Tab on any question, or start with ?" plus a switch to turn Ask off.
    - Intel or other unsupported Mac: "This Mac can't run Apple Intelligence."
    - macOS 14–25: "Needs macOS 26 or later."
    - Apple Intelligence off: "Turn on Apple Intelligence in System Settings → Apple Intelligence & Siri." [Open Settings]
    - Model downloading: "Apple Intelligence is still downloading its model. Ask turns on by itself when it's ready."
- **"Search the web for …":**
  - The Launcher doesn't have this row yet; only Text Actions has a web search. It will be added as a row offered when the model can't answer (Q2).
  - Opening it hands the query to your browser, the same as Text Actions' Search; it only happens when you choose it.
  - `SearchEngine` moves from Text Actions to OmniCore so both share it.

### Tests (fake engine, no model needed)
- Availability mapping for every reason, plus "OS too old" and "framework missing".
- Unsupported Mac: Tab and "?" don't enter Ask mode, and the Settings line says why.
- Streaming: snapshots replace the text, and the final state is answered.
- Cancellation: Esc ends the stream task, keeps the partial text, sets the stopped state, and the next question works.
- Context:
  - A follow-up reuses the same conversation, so the fake sees both prompts in one conversation.
  - Close → `reset()` → the next question gets a new conversation with no turns.
  - Overflow → a new conversation plus the notice.
- Error kinds: refusal and unsupported language offer web search; busy shows a message.
- Attachments:
  - The prompt contains an attachment only when it was attached.
  - Concealed clipboard content and over-long text are refused.
- One answer at a time: asking while answering is ignored.
- A source scan confirms OmniAI and FeaturePalette never mention `PrivateCloudComputeLanguageModel` and never pass a question or answer to a logger call.

### Risks
- **Answer quality:** the small on-device model can be wrong or vague. The notice says so, and the instructions ask it to admit when it doesn't know.
- **Context:** 4,096 tokens is small. Long follow-ups start over (with a notice), and attachments are capped.
- **Languages:** not every language is supported (Georgian very likely isn't). Unsupported questions get the "can't answer" message with web search.
- **First answer:** may be slow while the model loads. Omni prewarms the session when Ask mode starts.
- **Live testing:** depends on Apple Intelligence being on and the model downloaded on this Mac; the tests use a fake engine.

### Decisions needed
| # | Question | My recommendation |
|---|---|---|
| Q1 | Keys in Ask mode: Tab or ↩ (with text typed) asks a follow-up; ↩ on an empty field copies; ⌘↩ pastes; Esc stops, then closes. | As described |
| Q2 | "Search the web for …" is new in the Launcher. Show it only when the model can't answer, or also as the Launcher's general "no results" row? Which search engine: share one setting with Text Actions (moved to General), or a separate Launcher setting? | Only when the model can't answer; one shared engine setting in General (default Google) |
| Q3 | "Attach Selection" via Accessibility only (it won't work in most Electron/Chromium apps, where Clipboard still does), and a 6,000-character cap per attachment? | Yes |
| Q4 | Ask on by default when the Mac supports it (Settings → Launcher can turn it off)? | Yes |


## 10. Capture Text (Screenshots feature)

- **Replaces "Copy Text from Screen"** (same action ID `screenshots.text`, so there's one command, not two).
  - The new default shortcut is ⌘⇧2 (it was ⌃⌥⌘O); you can rebind it. macOS doesn't use ⌘⇧2.
  - It's reachable from the Launcher command "Capture Text" and from the Screenshot icon's menu.
- **Flow:** the selection overlay (drag an area or click a window), then Vision text recognition plus barcode detection on the same image. The text goes to the clipboard and a notice says "Copied N characters". No editor window.
- **QR codes and barcodes:** if any are found, their content is copied instead of the recognized text (several are joined with new lines). If the content is a web link (http/https), the notice gets an **Open** button.
- **Append:** holding ⇧ when the selection ends adds the new text to the previous capture (a new line between them, or a space in paragraph mode). Otherwise the capture replaces it. The last capture is kept in memory only, until Omni quits.
- **Clipboard History:** the clipboard item carries the marker type `com.george.omni.capturedText`. History records it with the source "Captured text" (a text.viewfinder icon in the history list) instead of the app under the selection.
- **Empty result:** the notice says "No text found" and the clipboard is left unchanged.
- **Settings:**
  - Line breaks: keep them, or join everything into one paragraph.
  - Recognition languages: chosen from `VNRecognizeTextRequest.supportedRecognitionLanguages()` (accurate level) on this Mac.
  - Automatic language detection: off by default, because some macOS 27 versions are slow with it.
  - Read captured text aloud: off by default; it uses AVSpeechSynthesizer and stops when the next capture starts.
- **Vision on this Mac** (macOS 27.0.1, accurate, revision 3) recognizes 33 languages:
  - English, French, Italian, German, Spanish, Portuguese (Brazil)
  - Chinese (Simplified and Traditional), Cantonese (Simplified and Traditional), Korean, Japanese
  - Russian, Ukrainian, Thai, Vietnamese, Arabic, Najdi Arabic, Turkish, Indonesian, Czech, Danish, Dutch
  - Norwegian (no, nn, nb), Malay, Polish, Romanian, Swedish, Finnish, Hindi, Marathi
  - **Georgian is not supported.** The fast level offers only the first six.
- **Tests:** line-break handling (keep, join, whitespace, blank lines), append (with and without a previous capture, both modes, Shift without a previous capture), the empty case (nothing to write, clipboard unchanged), barcode priority and link detection, and the captured-text marker in clipboard history.
