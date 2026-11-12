# Omni: Interface and onboarding

Goal: a new user understands Omni in one minute and reaches the main actions in one click.

Rules for this phase: UI only. No feature behaviour changes, all existing tests keep passing, and new tests cover the new settings and menu bar configuration.

Mockups are text sketches: `[ ]` is a button, `( )`/`(•)` a radio, `[x]`/`[ ]` a checkbox or switch, `⟨…⟩` a field, `▸` a submenu. Icon names in `{braces}` are SF Symbols.

---

## 0. Names and words

Plain names everywhere. Feature IDs and stored settings don't change, so nothing is lost.

| Today | New name | One-line description (shown everywhere) |
|---|---|---|
| Command Palette | **Launcher** | Open apps, settings and commands, and do quick math, from one search box. |
| Clipboard History | **Clipboard History** | Remembers what you copy so you can paste it again later. |
| Snippets | **Text Snippets** | Type a short code like ;sig in any app to insert text you use often. |
| Window Management | **Window Layouts** | Snap windows to halves, thirds and corners with a shortcut. |
| Window Switcher | **Window Switcher** | Hold ⌥ and press Tab to jump to any window, not just any app. |
| Keep Awake | **Keep Awake** | Stops your Mac from going to sleep for as long as you choose. |
| Keyboard Cleaning | **Lock Keyboard** | Locks the keyboard so you can wipe it. Unlock with the mouse. |
| System Stats | **System Stats** | Shows CPU, memory, network and battery in the menu bar. |
| Shortcut Overlay | **Shortcut Cheat Sheet** | Press ⌘ twice and hold to see the shortcuts of the app you're in. |
| Text Selection Popup | **Text Actions** | Select text in any app to copy, search, translate or change its case. |
| Screenshots | **Screenshots & Recording** | Capture, mark up and pin screenshots, copy text from images, record the screen. |
| Diagnostics | hidden (see §4.6) | — |

Words to remove from user-facing text:
- **Internal terms:** event tap, listen-only, fail open, AX, Accessibility API (use "Accessibility permission"), HUD, provider, keyword, SCK, fallback.
- **Raw settings:** bundle IDs, key codes.

For example, today's "Search it from the palette with “clip”" becomes "Press ⌃⌥V to see it". Detailed technical notes stay in PLAN.md, not in the app.

---

## 1. Menu bar quick-access icons

### 1.1 What the menu bar looks like

```
  … {cup.and.saucer} {camera.viewfinder} {doc.on.clipboard}  {Omni}   Wi-Fi  Battery  Thu 17:20
      Keep Awake       Screenshot          Clipboard          main icon
```

- **Order:** the main Omni icon is always rightmost of Omni's icons. Quick-access icons sit to its left in the order chosen in Settings → Menu Bar.
- **Keep Awake state:** the cup is outlined when off and filled (`cup.and.saucer.fill`) when on. Its tooltip says "Keep Awake: on until 18:30" or "Keep Awake: off".
- **While recording:** the Screen Recording icon becomes a red `● 0:42` and stops the recording on left-click. When the Record icon is hidden or in one-icon mode, the main icon shows `● 0:42` instead. Today's separate ● item goes away.
- **Feature off:** an icon is shown only while its feature is on. Settings → Menu Bar explains this and has a "Turn On" button next to the icon.

| Icon | Default | Left-click | Right-click |
|---|---|---|---|
| Keep Awake `{cup.and.saucer}` | **on** | Toggle (until turned off) | Durations, display option, settings |
| Screenshot `{camera.viewfinder}` | **on** | Capture area or window | Capture modes, after-capture choice, folder |
| Clipboard `{doc.on.clipboard}` | **on** | Show clipboard history | Recent items, clear history |
| Screen Recording `{record.circle}` | off | Start (choose area) / stop | Frame rate, audio, folder |
| Lock Keyboard `{keyboard.badge.ellipsis}` | off | Lock now | Time limit |
| Window Layouts `{rectangle.split.2x1}` | off | Small layout grid (same as §2) | Every layout with its shortcut, gap, drag-to-edge |

### 1.2 Right-click menus

Every quick-access menu ends with "<Feature> Settings…" and "Hide This Icon".

```
Keep Awake                         Screenshot
┌──────────────────────────────┐   ┌──────────────────────────────────────┐
│ On, until turned off         │   │ Capture Area or Window        ⌃⌥⌘4  │
│──────────────────────────────│   │ Capture Screen                ⌃⌥⌘3  │
│ Turn Off               ⌃⌥⌘A  │   │ Copy Text from Screen         ⌃⌥⌘O  │
│ For 15 Minutes               │   │ Scrolling Capture (Experimental)     │  ← only if turned on
│ For 30 Minutes               │   │──────────────────────────────────────│
│ For 1 Hour                   │   │ Record Screen                 ⌃⌥⌘R  │
│ For 2 Hours                  │   │──────────────────────────────────────│
│ For 5 Hours                  │   │ After Capturing              ▸ (•) Open in Editor
│ Until Turned Off             │   │                                ( ) Copy
│──────────────────────────────│   │                                ( ) Save
│ ✓ Keep the Display On        │   │                                ( ) Pin on Screen
│ While Certain Apps Run…      │   │ Open Screenshots Folder              │
│──────────────────────────────│   │──────────────────────────────────────│
│ Keep Awake Settings…         │   │ Screenshot Settings…                 │
│ Hide This Icon               │   │ Hide This Icon                       │
└──────────────────────────────┘   └──────────────────────────────────────┘

Clipboard                                   Screen Recording
┌──────────────────────────────────────┐    ┌──────────────────────────────────┐
│ Show Clipboard History        ⌃⌥V   │    │ Record Screen…            ⌃⌥⌘R  │
│──────────────────────────────────────│    │──────────────────────────────────│
│ Meeting notes for Thursday…   2m    │    │ Frame Rate ▸ (•) 30  ( ) 60       │
│ https://example.com/report    5m    │    │ ✓ Show the Pointer                │
│ {photo} Image 1200×800        1h    │    │   Record System Audio             │
│   (click pastes; last 5 items)       │    │   Record the Microphone           │
│──────────────────────────────────────│    │ Open Recordings Folder            │
│ Clear History…                       │    │──────────────────────────────────│
│──────────────────────────────────────│    │ Recording Settings…               │
│ Clipboard Settings…                  │    │ Hide This Icon                    │
│ Hide This Icon                       │    └──────────────────────────────────┘
└──────────────────────────────────────┘
  "Clear History…" asks: "Delete 214 items from your clipboard history?
   Pinned items are kept."  [Cancel] [Delete]

Lock Keyboard                        Window Layouts
┌────────────────────────────┐       ┌──────────────────────────────────────┐
│ Lock Keyboard Now   ⌃⌥⌘L   │       │ Left Half                    ⌃⌥←    │
│────────────────────────────│       │ Right Half                   ⌃⌥→    │
│ Unlock Automatically After ▸│       │ … (all 18 layouts)                  │
│   ( ) 30 s (•) 1 min        │       │ Restore Previous Size        ⌃⌥⌫    │
│   ( ) 2 min ( ) 5 min       │       │──────────────────────────────────────│
│   ( ) 10 min                │       │ Gap Between Windows ▸ 0 / 4 / 8 / 16 │
│────────────────────────────│       │ ✓ Snap by Dragging to Screen Edges   │
│ Lock Keyboard Settings…    │       │──────────────────────────────────────│
│ Hide This Icon             │       │ Window Layout Settings…              │
└────────────────────────────┘       │ Hide This Icon                       │
                                     └──────────────────────────────────────┘
```

- **Empty clipboard:** the recent-items block shows "Nothing copied yet. Copy something to see it here."
- **Paste target:** pasting from these menus pastes into the app you were using; the menu never takes focus away from it.

### 1.3 Main icon

- **Left-click:** opens the control panel (§2).
- **Right-click:** a short menu:

```
┌────────────────────────────┐
│ Open Control Panel   ⌃⌥⌘M  │
│ Settings…              ⌘,  │
│ Setup Guide…               │
│────────────────────────────│
│ About Omni                 │
│ Quit Omni              ⌘Q  │
└────────────────────────────┘
```

- **New shortcut:** "Open control panel", default ⌃⌥⌘M, rebindable. It's free among Omni's defaults.

### 1.4 Settings → Menu Bar

```
┌ Menu Bar ───────────────────────────────────────────────────────────┐
│ Icons in the menu bar                                               │
│   (•) Separate icons for quick actions                              │
│   ( ) One icon only: everything is in the control panel             │
│                                                                     │
│ Quick actions (drag ≡ to reorder; left to right as in the menu bar) │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ ≡  [x] {cup}        Keep Awake        click: turn on or off     │ │
│ │ ≡  [x] {camera}     Screenshot        click: capture an area    │ │
│ │ ≡  [x] {clipboard}  Clipboard         click: show history       │ │
│ │ ≡  [ ] {record}     Screen Recording  click: start recording    │ │
│ │ ≡  [ ] {keyboard}   Lock Keyboard     click: lock now           │ │
│ │ ≡  [ ] {split}      Window Layouts    off: Window Layouts is    │ │
│ │                                       turned off   [Turn On]    │ │
│ └─────────────────────────────────────────────────────────────────┘ │
│ Right-click any icon for its options.                               │
│                                                                     │
│ System Stats has its own menu bar item (Settings → System Stats).   │
│ In one-icon mode its numbers move into the control panel instead.   │
│                                                                     │
│ On Macs with a notch, macOS hides menu bar icons that don't fit.    │
│ If an icon is missing, try "One icon only".                         │
│                                                    [Reset to Defaults]
└─────────────────────────────────────────────────────────────────────┘
```

- **Reorder by keyboard:** each row has ⌥↑ and ⌥↓ (also in its context menu: "Move Left", "Move Right").
- **One-icon mode:** greys out the list. The settings are kept for when you switch back.

---

## 2. Control panel

The control panel is a popover-style panel under the main icon.

- **It doesn't take focus from your app.** It's built like the Launcher: it receives the keyboard, but the app you were using stays the active app. That's why "paste" and window layouts act on that app and window.
- **Width:** 400 pt.

### 2.1 Normal state

```
╭───────────────────────────────────────────────────────────────╮
│  Omni                                        ⌃⌥⌘M       {gear}│
├───────────────────────────────────────────────────────────────┤
│ ┌──────────┐┌──────────┐┌──────────┐┌──────────┐┌──────────┐ │
│ │ {camera} ││ {record} ││{clipbrd} ││  {cup}   ││{keyboard}│ │
│ │Screenshot││  Record  ││Clipboard ││Keep Awake││   Lock   │ │
│ │  ⌃⌥⌘4    ││  ⌃⌥⌘R    ││   ⌃⌥V    ││  ⌃⌥⌘A    ││  ⌃⌥⌘L    │ │
│ └──────────┘└──────────┘└──────────┘└──────────┘└──────────┘ │
│                                                               │
│ RECENTLY COPIED                                    Show All ⌃⌥V│
│  1  Meeting notes for Thursday: agenda, budget…   Slack · 2m  │
│  2  https://example.com/report                    Safari · 5m │
│  3  {thumbnail} Image 1200 × 800                  Preview · 1h│
│                                                               │
│ WINDOW · Safari, "Apple"                                      │
│  [▌  ] [  ▐] [▌  ] [ ▐ ] [  ▌] [████]                         │
│  Left   Right  Left  Center Right  Maximize                    │
│  half   half   third third  third                              │
│  ⌃⌥←    ⌃⌥→    ⌃⌥D   ⌃⌥F    ⌃⌥G    ⌃⌥↩                         │
├───────────────────────────────────────────────────────────────┤
│ CPU 12% · Memory 61% · ↓ 1.2 MB/s ↑ 40 KB/s · Battery 84%     │
│ Settings…  ⌘,                                    Quit Omni  ⌘Q │
╰───────────────────────────────────────────────────────────────╯
```

- **Action buttons:** Screenshot = capture area or window. Record = choose an area and start. Clipboard = show history. Keep Awake = toggle. Lock = lock the keyboard. Right-clicking a button (or pressing ⇧↩ on it) opens the same options menu as its menu bar icon (§1.2).
- **Keep Awake on:** the tile is tinted with the accent color, shows a filled cup, and its label reads "Keep Awake · until 18:30" or "Keep Awake · On".
- **While recording:** the Record tile is red and reads "Stop · 0:42".
- **Recent items:** click, ↩ or 1–3 pastes into the app you were using and closes the panel. Text items are clipped to one line. Images show a 28 pt thumbnail, files their icon and name.
- **Window line:** names the window the layouts will act on. If there isn't one, it reads "No window to arrange" and the tiles are disabled.
- **Stats line:** shown only when System Stats is on. It uses the stats the user chose, plus battery when there is one.

### 2.2 When features are off, and empty states

```
│ ┌──────────┐                                                  │
│ │ {camera} │   dimmed tile with "Off" in place of the shortcut │
│ │Screenshot│   click → inline: "Screenshots & Recording is off.│
│ │   Off    │   [Turn On]"  (then permission prompt if needed)  │
│ └──────────┘                                                  │
│ RECENTLY COPIED                                               │
│   Nothing copied yet. Copy something to see it here.          │
│   (Clipboard History off: "Turn on Clipboard History to see   │
│    what you copied here. [Turn On]")                          │
│ WINDOW                                                        │
│   Turn on Window Layouts to arrange windows from here.        │
│   [Turn On]                                                   │
```

- **Missing permission:** a feature that's on but waiting for a permission shows its tile with an orange `{exclamationmark.triangle}` and "Needs permission". Clicking it opens the exact System Settings pane.

### 2.3 Keyboard

| Key | Action |
|---|---|
| ←→↑↓ | Move the focus ring through every control in reading order (tiles → recent items → layouts → Settings → Quit) |
| ↩ or Space | Activate the focused control |
| ⇧↩ | Options menu of the focused tile |
| 1 – 3 | Paste recent item 1–3 |
| ⌘, | Settings |
| ⌘Q | Quit |
| Esc | Close |

- **Focus ring:** always visible when the panel is opened by keyboard (⌃⌥⌘M). After a mouse open it appears on the first arrow key.
- **System setting not needed:** this doesn't depend on the macOS "Keyboard navigation" setting.

---

## 3. Onboarding (replaces today's two steps)

- **Window:** 640 × 520 pt, with progress dots at the bottom, [Back] / [Continue] buttons, and Esc to close.
- **Reopening:** it's available any time from Settings → General → "Open Setup Guide" and from the main icon's right-click menu.
- **Current users:** it doesn't run again automatically for anyone who already finished setup.

### Screen 1: What Omni does

```
╭──────────────────────────────────────────────────────────────╮
│                                                              │
│                         {Omni icon}                          │
│                                                              │
│      Omni adds the shortcuts your Mac is missing: one        │
│      menu bar app for screenshots, clipboard history,        │
│      window layouts, staying awake, and quick launching.     │
│                                                              │
│    {camera}     {clipboard}    {split}      {cup}   {magnif.}│
│   Screenshots   Clipboard     Windows    Keep Awake Launcher │
│                                                              │
│   Everything stays on this Mac.                              │
│                                                              │
│                                         [Get Started]        │
│                          ● ○ ○ ○                             │
╰──────────────────────────────────────────────────────────────╯
```

### Screen 2: Choose features

```
╭──────────────────────────────────────────────────────────────╮
│ Choose what you want                                         │
│ Start with our picks or choose your own. You can change      │
│ this any time in Settings.                                   │
│                                                              │
│ [ Recommended ]  [ Everything ]  [ None ]                    │
│                                                              │
│ [x] {magnif.}   Launcher                                     │
│                 Open apps, settings and commands from one box │
│ [x] {clipboard} Clipboard History                            │
│                 Remembers what you copy so you can paste it   │
│ [x] {split}     Window Layouts            needs Accessibility│
│                 Snap windows to halves, thirds and corners    │
│ [x] {cup}       Keep Awake                                   │
│                 Stops your Mac from going to sleep            │
│ [x] {camera}    Screenshots & Recording needs Screen Recording│
│                 Capture, mark up, pin and record the screen   │
│ ── More ─────────────────────────────────────────────────────│
│ [ ] Text Snippets · Window Switcher · Lock Keyboard ·        │
│     System Stats · Shortcut Cheat Sheet · Text Actions       │
│     (same row layout, scrolls)                               │
│                                                              │
│ [Back]                                       [Continue]      │
│                          ○ ● ○ ○                             │
╰──────────────────────────────────────────────────────────────╯
```

- **Recommended:** Launcher, Clipboard History, Window Layouts, Keep Awake, and Screenshots & Recording. These need only two permissions: Accessibility and Screen Recording.
- **Choices take effect only on Continue,** so going Back and changing your mind doesn't briefly start anything.

### Screen 3: Permissions (only for the chosen features)

```
╭──────────────────────────────────────────────────────────────╮
│ Allow what your features need                                │
│ macOS asks you to allow these yourself. Nothing you allow    │
│ leaves this Mac.                                             │
│                                                              │
│ ┌──────────────────────────────────────────────────────────┐ │
│ │ {checkmark.circle.fill} Accessibility            Allowed │ │  ← green
│ │ Lets Omni move windows and type snippets for you.        │ │
│ ├──────────────────────────────────────────────────────────┤ │
│ │ {circle} Screen Recording                  Not allowed   │ │
│ │ Lets Omni take screenshots and record your screen.       │ │
│ │                          [Open System Settings]          │ │  → Privacy & Security ›
│ │                                                          │ │    Screen & System Audio
│ │                                                          │ │    Recording
│ ├──────────────────────────────────────────────────────────┤ │
│ │ {circle.dashed} Microphone (optional)      Not asked yet │ │
│ │ Only for screen recordings with your voice.  [Allow…]    │ │
│ └──────────────────────────────────────────────────────────┘ │
│                                                              │
│ Used by: Window Layouts (Accessibility), Screenshots &       │
│ Recording (Screen Recording).                                │
│                                                              │
│ [Back]                    [Skip for Now]     [Continue]      │
│                          ○ ○ ● ○                             │
╰──────────────────────────────────────────────────────────────╯
```

- **Live status:** checked every second while this screen is open. Each row turns green with "Allowed" as soon as it's granted.
- **Restart needed:** if macOS needs Omni to restart before a grant takes effect (Screen Recording sometimes does), the row says "Allowed after Omni reopens" with a [Reopen Omni] button.
- **Blocked by macOS:** the row offers "Reset and ask again" (today's reset).
- **Skipping:** features without their permission wait, and Settings shows a banner with a one-click fix (§4.3).
- **None needed:** if the chosen features need no permissions, this screen says so in one line and Continue is the only button.

### Screen 4: Shortcuts and "Try it"

```
╭──────────────────────────────────────────────────────────────╮
│ You're set. A few shortcuts to remember:                      │
│                                                              │
│   ⌃⌥⌘M       Open the control panel (or click {Omni})        │
│   ⌃⌥Space    Open the Launcher                               │
│   ⌃⌥V        Clipboard history                               │
│   ⌃⌥⌘4       Screenshot an area or window                    │
│   ⌃⌥← / →    Move a window to the left / right half          │
│   ⌃⌥⌘A       Keep Awake on / off                             │
│                                                              │
│ Only shortcuts of the features you chose are listed. All of  │
│ them are in Settings → Shortcuts, where you can change them. │
│                                                              │
│ [Back]                  [Finish]    [Try It: Open the Panel] │
│                          ○ ○ ○ ●                             │
╰──────────────────────────────────────────────────────────────╯
```

- **Try It:** finishes onboarding and opens the control panel under the main icon.

---

## 4. Settings

### 4.1 Window layout

```
╭ Omni Settings ────────────────────────────────────────────────────────────╮
│ ⟨🔍 Search settings          ⟩ │                                          │
│                                │                                          │
│ {square.grid.2x2}  Overview    │            (selected page)               │
│ {menubar.rectangle} Menu Bar   │                                          │
│ {keyboard}         Shortcuts   │                                          │
│ {lock.shield}      Permissions │                                          │
│ {gearshape}        General     │                                          │
│                                │                                          │
│ FEATURES                       │                                          │
│ {magnif.}  Launcher          ● │   ● green = working                      │
│ {clipbrd}  Clipboard History ● │   ● orange = needs permission            │
│ {text}     Text Snippets     ○ │   ○ = off                                │
│ …                              │   ● red = problem                         │
╰───────────────────────────────────────────────────────────────────────────╯
```

- **Status dots:** each dot also has a text label for VoiceOver and as a tooltip, so color is never the only signal.
- **First page:** Settings opens on Overview the first time, then on the last page used.

### 4.2 Overview

```
┌ Overview ────────────────────────────────────────────────────────────────┐
│ ┌ {exclamationmark.triangle} 2 features are waiting for a permission. ─┐ │
│ │ Screenshots & Recording needs Screen Recording.     [Allow…]         │ │
│ │ Window Layouts needs Accessibility.                 [Allow…]         │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│ ┌──────────────────────────────┐ ┌──────────────────────────────┐        │
│ │ {magnif.} Launcher      [x]  │ │ {clipbrd} Clipboard History [x]│      │
│ │ Open apps, settings and      │ │ Remembers what you copy so   │        │
│ │ commands from one box.       │ │ you can paste it again.      │        │
│ │ ● Working          ⌃⌥Space   │ │ ● Working            ⌃⌥V     │        │
│ └──────────────────────────────┘ └──────────────────────────────┘        │
│ ┌──────────────────────────────┐ ┌──────────────────────────────┐        │
│ │ {camera} Screenshots &   [x] │ │ {text} Text Snippets     [ ] │        │
│ │ Recording                    │ │ Type a short code like ;sig  │        │
│ │ Capture, mark up and record. │ │ to insert text you use often.│        │
│ │ ● Needs permission [Allow…]  │ │ ○ Off                        │        │
│ └──────────────────────────────┘ └──────────────────────────────┘        │
│ … one card per feature, 2 columns (1 column when the window is narrow)   │
└──────────────────────────────────────────────────────────────────────────┘
```

- **Clicking a card** (outside its switch) opens that feature's page.
- **Shortcut shown:** the card shows the feature's main shortcut. Features without one show their gesture, e.g. "⌘ ⌘ hold" or "⌥ Tab".
- **Status words:**
  - Working
  - Needs permission
  - Off
  - Problem: <one line> (e.g. "macOS stopped its keyboard listener; turn it off and on")

### 4.3 Feature page

Every feature page has the same frame:

```
┌ Screenshots & Recording ─────────────────────────────────────────────────┐
│ {camera} Screenshots & Recording                                    [x]  │
│ Capture, mark up and pin screenshots, copy text from images, record the  │
│ screen.                                                                  │
│                                                                          │
│ ┌ {exclamationmark.triangle} Omni needs Screen Recording permission to ┐ │
│ │ take screenshots. Until then this feature is paused.                 │ │
│ │ [Open System Settings]                    Status updates by itself.  │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│ SHORTCUTS                                                                │
│   Capture area or window              ⟨⌃⌥⌘4⟩  {reset}                    │
│   …                                                                      │
│ (feature's own sections, unchanged in content, reworded where needed)    │
│                                                                          │
│ PERMISSIONS                                                              │
│   Screen Recording (required)        ○ Not allowed  [Open System Settings]
│   Microphone (optional)              ○ Not asked    [Allow…]             │
│   Accessibility (optional, for scrolling capture) ✓ Allowed             │
│                                                                          │
│                                          [Reset to Defaults…]            │
└──────────────────────────────────────────────────────────────────────────┘
```

- **The banner** appears only while a required permission is missing. It's the "one-click fix", never a silent failure, and it disappears by itself once the permission is granted.
- **Optional permissions** never show a banner. They show as rows, with a note where something is limited, e.g. "Without it: no window previews".
- **Settings while off:** today a feature's settings are hidden while it's off. They'll show, dimmed, with "Turn on Screenshots & Recording to change these", so people can see what they'd get.
- **Shortcuts section:** each feature page now lists its own shortcuts at the top, in addition to the Shortcuts page.
- **Reset to Defaults…** asks for confirmation:

  > Reset Screenshots & Recording settings? Options and shortcuts go back to their defaults. Your on/off choice is kept.

  It never deletes things you made: clipboard history items, snippets, Keep Awake's app list, or excluded-app lists.
- **Erase Data…** is a separate, red, clearly labeled button on features that keep your content (Clipboard History, Text Snippets, Keep Awake's app list, excluded-app lists, Launcher usage history). It says exactly what will be deleted, e.g. "Erase all 214 clipboard items, including pinned ones? This can't be undone.", and needs a second click on [Erase]. It's available while the feature is on.

### 4.4 Search

```
⟨🔍 frame rate                 ⟩
┌──────────────────────────────────────────────┐
│ Screenshots & Recording › Frame rate         │
│ Screenshots & Recording › Show the pointer   │  (matched "frame" via keywords)
│ System Stats › Refresh every                 │
└──────────────────────────────────────────────┘
```

- **Results:** while you type, the sidebar is replaced by results. Each one reads "Page › Setting".
- **Choosing a result** opens the page, scrolls to that setting and briefly highlights it (no animation with Reduce Motion).
- **What's searchable:** every setting label, plus a few synonyms per setting ("caffeine" → Keep Awake, "OCR" → Copy text from screen), feature names and descriptions, shortcut titles, and page names.
- **No match:** "No settings match “xyz”."

### 4.5 Shortcuts page

```
┌ Shortcuts ──────────────────────────────────────────────────────────────────┐
│ ⟨🔍 Filter⟩                                       Show: (•) All ( ) On only │
│                                                                             │
│  Action                          Feature                Shortcut            │
│ ─────────────────────────────────────────────────────────────────────────── │
│  Open the control panel          Omni                   ⟨⌃⌥⌘M⟩   {reset}   │
│  Open the Launcher               Launcher               ⟨⌃⌥Space⟩ {reset}  │
│  Show clipboard history          Clipboard History      ⟨⌃⌥V⟩    {reset}   │
│  Capture area or window          Screenshots & Rec.     ⟨⌃⌥⌘4⟩   {reset}   │
│  Left half                       Window Layouts         ⟨⌃⌥←⟩    {reset}   │
│ {⚠} Lock keyboard now            Lock Keyboard (off)    ⟨⌃⌥⌘A⟩   {reset}   │
│     Same as "Keep Awake on / off". One of them won't work. [Change…]        │
│  Switch windows                  Window Switcher        ⌥ Tab   (gesture)   │
│  Show app shortcuts              Shortcut Cheat Sheet   ⌘ ⌘ hold (gesture)  │
│  Insert a snippet                Text Snippets          type ;code (gesture)│
│ ─────────────────────────────────────────────────────────────────────────── │
│ Shortcuts of features that are off are listed in grey and can be changed.   │
│ A shortcut another app already uses is marked "Used by another app".        │
│                                              [Reset All Shortcuts…]         │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Columns:** one table for all shortcuts, sortable by Action and Feature.
- **Conflicts:**
  - between two Omni shortcuts, including features that are off ("will conflict when turned on")
  - with another app ("Used by another app")
  - shortcuts macOS rejects
- **Gesture rows** (double-press, ⌥Tab, snippet codes) aren't recordable shortcuts. They link to the setting that changes them.

### 4.6 Permissions, General, and Diagnostics

- **Permissions:**
  - Same rows as onboarding screen 3, for every permission any turned-on feature uses.
  - Each row also says which features use it.
  - The App Management line goes away (see §7).
- **General:**
  - Open at login
  - Open Setup Guide…
  - Language: shows "English" and is disabled until translations exist
  - About / version
  - Reset All Settings…
- **Diagnostics:**
  - **Hidden:** it's not listed anywhere unless ⌥ is held while Settings opens (from the menu, ⌘, or the control panel). Then a "Diagnostics" page appears at the bottom of the sidebar with today's test shortcut and its counter.
  - **New default:** off for new users. Your current state (on) is kept (see Q4).

---

## 5. Consistency

### 5.1 One visual style

| Token | Value |
|---|---|
| Panel material | `.popover` for the control panel and menus' custom views; `.hudWindow` for notices (HUD) and overlays (unchanged) |
| Corner radius | 12 pt panels, 10 pt cards and tiles, 6 pt small controls |
| Spacing | 4 / 8 / 12 / 16 / 24 pt scale only |
| Text | Title: `.title2` semibold; section headers: `.caption` uppercase secondary; body `.body`; help text `.callout` secondary |
| Colors | System only: accent, `.secondary`, green (working), orange (needs permission), red (problem). Status always with an icon and word |
| Icons | SF Symbols, `.hierarchical` rendering, one symbol per feature everywhere (menu bar, cards, sidebar, onboarding) |
| Shortcut chips | Monospaced digits in a rounded `.quaternary` capsule, the same component everywhere |

- **Shared components:** they live in one file (`OmniUI`, in OmniPlatform): `ShortcutChip`, `StatusBadge`, `FeatureCard`, `PermissionBanner`, `EmptyState`, `SectionHeader`, and `PanelBackground`. Every window and popover uses them.
- **Light and dark:** both come from system materials and colors. Mockups will be checked in both, with the accent set to Graphite and to Multicolor.
- **Reduce Motion** (`accessibilityDisplayShouldReduceMotion`): no fades or slides. The HUD, control panel, search highlight and onboarding page changes appear and disappear instantly.
- **Increase Contrast:** panels, cards and the HUD get a 1 pt `.separator` border, and secondary text uses `.primary` at 80%.
- **Reduce Transparency:** the system turns materials opaque by itself. We check that text stays readable.
- **VoiceOver:** every icon-only button gets a label, and tiles read as "Screenshot, button, shortcut Control Option Command 4".

### 5.2 Empty states

| Where | Text |
|---|---|
| Clipboard history (Launcher scoped) | Nothing copied yet. Copy something to see it here. |
| Control panel: recent items | Nothing copied yet. Copy something to see it here. |
| Text Snippets list | No snippets yet. Add one, then type its code (like ;sig) in any app. [Add Snippet] |
| Keep Awake: app list | No apps yet. Add an app to stay awake while it's running. [Add App…] |
| Excluded apps lists | No apps excluded. |
| Shortcuts filter, no match | No shortcuts match “xyz”. |
| Settings search, no match | No settings match “xyz”. |
| Launcher, no results | No results for “xyz”. Press ↩ to search the web? (only if Text Actions' search engine is set; otherwise just the first sentence) |
| Window line in control panel | No window to arrange. Click a window, then open the panel again. |
| Shortcut Cheat Sheet, app without menu shortcuts | (exists) No keyboard shortcuts in <App>'s menus. |

### 5.3 Strings in one place

- **One catalog:** all user-facing text moves to a single `L10n.swift` in OmniCore, grouped by area (`L10n.Clipboard.emptyHistory`, `L10n.Onboarding.welcomeTitle`, …), backed by one `Localizable.xcstrings` String Catalog (English now).
- **Every module reads from it,** so a translator edits one file.
- **How strings are written:**
  - Numbers and names use format placeholders, never string concatenation.
  - Plurals use String Catalog plural variants ("1 item" / "214 items").
  - Shortcut symbols (⌘⌥⌃⇧) are not translated.
- **Not user-facing:** log messages stay as they are, in English.
- **Enforced by a check:** a `Scripts/check-strings.sh` step in `make build` fails when a string literal is passed to `Text`, `Button`, `Toggle`, `Label`, `HUD.show`, alert titles or menu items outside `L10n.swift`.

---

## 6. How it's built (UI only)

These are small additions for display. No feature's behaviour changes.

- **`QuickAccess` descriptor** (OmniCore): each feature that has a menu bar icon or control panel tile describes:
  - its icon (normal and active)
  - its title
  - its primary command ID
  - an "is active" flag it already has (Keep Awake session, recording state)
  - its options menu as a pure `MenuModel`: items, toggles, radio groups, submenus, separators
  
  The icons, the control panel and the right-click menus are all built from these descriptors. Actions call the **existing commands** (`screenshots.area`, `keepawake.30`, `clipboard.clear`, `windows.leftHalf`, …).
- **Read-only hooks added:** Keep Awake's current session and end time (already stored), the recording state and elapsed time, and System Stats' latest snapshot. All three already exist inside the features; they're only exposed for display.
- **`MenuBarConfiguration`** (pure value, persisted under `app.menuBar`): mode, ordered items, and visibility, plus `visibleItems(featureStates:)`.
- **`SettingsIndex`** (pure): entries (page, label, keywords, anchor ID) and a ranked search.
- **`SettingsReset`** (pure): the keys a feature reset removes. User-made content is excluded.
- **`ShortcutTable`** (pure):
  - every declared shortcut, including features that are off
  - each one's state: active, conflict with another Omni shortcut (including future conflicts), used by another app
  - gesture rows
  
  For this, each feature declares its shortcut list as data; today they're only known once the feature is on.
- **Control panel:** a non-activating panel (`NSPanel` like the Launcher), with a SwiftUI view and its own keyboard focus handling.
- **Removed:** today's single-menu `StatusItemController`, and the separate recording ● item (the indicator moves as described in §1.1).

### Tests to add

- `MenuBarConfiguration`:
  - defaults (three on, three off)
  - reorder (move up/down, drag index math)
  - hide/show, one-icon mode keeps the list, unknown/removed items ignored
  - Codable round trip and migration from "no setting yet"
  - visible items depend on which features are on
- `ControlPanelModel`:
  - which tiles show and whether they're enabled, off, need a permission, or are active
  - keyboard focus order and wrap-around
  - 1–3 shortcuts map to recent items
  - empty states chosen correctly
- `MenuModel` builders: each quick-access menu has the expected items and commands for given states (e.g. Keep Awake on shows "Turn Off" first, the scrolling capture item only when enabled).
- `SettingsIndex`: finds labels, synonyms and feature names; ranking puts exact label matches first; no duplicates; every entry's page exists.
- `SettingsReset`: removes the feature's option keys and shortcut overrides, keeps on/off and user content, and doesn't touch other features.
- `ShortcutTable`:
  - conflicts between features (including off ones)
  - "used by another app" state passes through
  - gesture rows present
  - a reset clears overrides
- Onboarding model: the recommended set, Everything/None presets, the permission union for a choice (required vs optional), and that choices apply only on Continue.
- Strings: every `L10n` key has an English value in the catalog, there are no duplicate keys, and placeholders are consistent. The `check-strings.sh` script itself gets a fixture test.

All existing tests must keep passing. The exceptions are the two registry tests in §7 (approved), plus the Full Disk Access heuristic test, which is deleted together with the code it tested.

---

## 7. Removing the cancelled phases from the app

- **Permissions:** remove the two permission kinds only those phases would have used, Full Disk Access and App Management. This includes their texts, the Full Disk Access probe and the "App Management can't be checked" note in Settings → Permissions.
  - **Tests affected:** two existing registry tests used them as stand-in permissions and now use Screen Recording and Microphone, with the assertions unchanged. The Full Disk Access detection test is deleted with that code.
- **Launcher:** it can still open the macOS "Full Disk Access" and "App Management" panes of System Settings. Those are macOS pages, not Omni features, so they stay.
- **PLAN.md:** has already been cleaned. It no longer mentions the cancelled phases, their modules, permissions or decisions.

---

## 8. Decisions (approved 2026-11-12)

| # | Question | My recommendation |
|---|---|---|
| Q2 | Remove the now-unused Full Disk Access and App Management permission kinds? | **Approved:** removed; the two registry tests use Screen Recording and Microphone |
| Q3 | "Reset to Defaults" per feature: keep user-made content? | **Approved:** reset keeps user content. Each feature with data also gets a separate, clearly labeled **Erase Data…** with confirmation (§4.3) |
| Q4 | Diagnostics off by default for new users, current setting kept? | **Approved** |
| Q5 | The new names in §0? | **Approved** |
| Q6 | Control panel shortcut ⌃⌥⌘M? | **Approved** |
| Q7 | Languages? | **Approved:** English only, every string in the String Catalog |
