import Foundation

public extension L10n {
    /// Window Layouts (feature id `windows`).
    enum Windows {
        public static var displayName: String { tr("windows.displayName", "Window Layouts") }
        public static var summary: String { tr("windows.summary", "Snap windows to halves, thirds and corners with a shortcut.") }
        public static var commandSubtitle: String { tr("windows.command.subtitle", "Window") }

        // Layouts
        public static var leftHalf: String { tr("windows.action.leftHalf", "Left Half") }
        public static var rightHalf: String { tr("windows.action.rightHalf", "Right Half") }
        public static var topHalf: String { tr("windows.action.topHalf", "Top Half") }
        public static var bottomHalf: String { tr("windows.action.bottomHalf", "Bottom Half") }
        public static var firstThird: String { tr("windows.action.firstThird", "First Third") }
        public static var centerThird: String { tr("windows.action.centerThird", "Center Third") }
        public static var lastThird: String { tr("windows.action.lastThird", "Last Third") }
        public static var firstTwoThirds: String { tr("windows.action.firstTwoThirds", "First Two Thirds") }
        public static var lastTwoThirds: String { tr("windows.action.lastTwoThirds", "Last Two Thirds") }
        public static var topLeft: String { tr("windows.action.topLeft", "Top Left Quarter") }
        public static var topRight: String { tr("windows.action.topRight", "Top Right Quarter") }
        public static var bottomLeft: String { tr("windows.action.bottomLeft", "Bottom Left Quarter") }
        public static var bottomRight: String { tr("windows.action.bottomRight", "Bottom Right Quarter") }
        public static var maximize: String { tr("windows.action.maximize", "Maximize") }
        public static var center: String { tr("windows.action.center", "Center") }
        public static var nextDisplay: String { tr("windows.action.nextDisplay", "Move to Next Display") }
        public static var previousDisplay: String { tr("windows.action.previousDisplay", "Move to Previous Display") }
        public static var restore: String { tr("windows.action.restore", "Restore Previous Size") }

        // Notices
        public static var noWindow: String { tr("windows.notice.noWindow", "No window to arrange") }
        public static var fullScreen: String { tr("windows.notice.fullScreen", "Window is in full screen") }
        public static var nothingToRestore: String { tr("windows.notice.nothingToRestore", "Nothing to restore") }
        public static var onlyOneDisplay: String { tr("windows.notice.onlyOneDisplay", "Only one display connected") }
        public static var cantArrange: String { tr("windows.notice.cantArrange", "This window can't be arranged") }

        // Settings and menu
        public static var gap: String { tr("windows.settings.gap", "Gap between windows") }
        public static var gapMenu: String { tr("windows.menu.gap", "Gap Between Windows") }
        public static func gapPoints(_ points: Int) -> String { format("windows.settings.gapPoints", "%lld pt", points) }
        public static var dragToEdge: String { tr("windows.settings.dragToEdge", "Snap by dragging a window to a screen edge") }
        public static var dragToEdgeMenu: String { tr("windows.menu.dragToEdge", "Snap by Dragging to Screen Edges") }
        public static var dragToEdgeHelp: String {
            tr("windows.settings.dragToEdgeHelp", "Edges snap to halves, corners to quarters, the top edge maximizes. Edges shared with another display don't snap.")
        }
        public static var dragToEdgeFailed: String {
            tr("windows.settings.dragToEdgeFailed", "Snapping by dragging couldn't start. Check that Omni has the Accessibility permission, then turn it off and on.")
        }
        public static var shortcutsHelp: String {
            tr("windows.settings.shortcutsHelp", "Change the shortcuts above or on the Shortcuts page. Every layout is also in the Launcher.")
        }
        public static var clickHint: String { tr("windows.quick.clickHint", "show layouts") }
    }

    /// Window Switcher (feature id `switcher`).
    enum Switcher {
        public static var displayName: String { tr("switcher.displayName", "Window Switcher") }
        public static var summary: String { tr("switcher.summary", "Hold ⌥ and press Tab to jump to any window, not just any app.") }
        public static var gestureTitle: String { tr("switcher.gesture.title", "Switch windows") }
        public static var searchCommand: String { tr("switcher.command.search", "Switch to Window…") }
        public static var searchTitle: String { tr("switcher.search.title", "Window") }
        public static var noWindows: String { tr("switcher.notice.noWindows", "No windows to switch to") }
        public static var cantClose: String { tr("switcher.notice.cantClose", "This window can't be closed from here") }
        public static var paused: String { tr("switcher.notice.paused", "Window Switcher paused: macOS stopped its keyboard listener") }

        // Window states
        public static var stateOpen: String { tr("switcher.state.open", "Open") }
        public static var stateMinimized: String { tr("switcher.state.minimized", "Minimized") }
        public static var stateHidden: String { tr("switcher.state.hidden", "Hidden") }
        public static var stateOtherSpace: String { tr("switcher.state.otherSpace", "Other Space") }
        /// "Safari · Minimized"
        public static func appWithState(_ app: String, _ state: String) -> String {
            format("switcher.appWithState", "%@ · %@", app, state)
        }

        // Settings
        public static var trigger: String { tr("switcher.settings.trigger", "Shortcut") }
        public static func replacesAppSwitcher(_ keys: String) -> String {
            format("switcher.settings.replacesAppSwitcher", "%@ (replaces the app switcher)", keys)
        }
        public static var triggerHelp: String {
            tr("switcher.settings.triggerHelp", "Hold the key and press Tab to move forward (add ⇧ to go back), then let go to switch. While it's open: arrows move, ↩ switches, Esc cancels, Q quits the app, W closes the window.")
        }
        public static var thumbnails: String { tr("switcher.settings.thumbnails", "Show live previews (needs Screen Recording)") }
        public static var includeMinimized: String { tr("switcher.settings.includeMinimized", "Include minimized windows") }
        public static var includeHidden: String { tr("switcher.settings.includeHidden", "Include windows of hidden apps") }
        public static var includeOtherSpaces: String { tr("switcher.settings.includeOtherSpaces", "Include windows on other Spaces") }
        public static var otherSpacesHelp: String {
            tr("switcher.settings.otherSpacesHelp", "Windows on other Spaces need Screen Recording to be listed. Choosing one brings its app forward; macOS decides whether to switch Space.")
        }
        public static var stoppedHelp: String {
            tr("switcher.settings.stoppedHelp", "macOS stopped the switcher's keyboard listener, so it has been paused and your keyboard works normally. Turn Window Switcher off and on to restart it.")
        }
    }

    /// Keep Awake (feature id `keepawake`).
    enum KeepAwake {
        public static var displayName: String { tr("keepawake.displayName", "Keep Awake") }
        public static var summary: String { tr("keepawake.summary", "Stops your Mac from going to sleep for as long as you choose.") }
        public static var toggleHotkey: String { tr("keepawake.hotkey.toggle", "Keep Awake on / off") }
        public static var commandOn: String { tr("keepawake.command.on", "Keep Awake") }
        public static var commandOnSubtitle: String { tr("keepawake.command.onSubtitle", "Until turned off") }
        public static func commandFor(_ duration: String) -> String { format("keepawake.command.for", "Keep Awake for %@", duration) }
        public static var commandOff: String { tr("keepawake.command.off", "Stop Keeping Awake") }
        public static var sleepAllowed: String { tr("keepawake.notice.sleepAllowed", "Sleep allowed again") }

        // Durations
        public static func minutes(_ count: Int) -> String { plural("keepawake.duration.minutes", one: "%lld Minute", other: "%lld Minutes", count) }
        public static func hours(_ count: Int) -> String { plural("keepawake.duration.hours", one: "%lld Hour", other: "%lld Hours", count) }

        // Status sentence, e.g. "Keeping awake until 18:30 and while Xcode is running"
        public static func keepingAwake(_ reasons: String) -> String { format("keepawake.status.keepingAwake", "Keeping awake %@", reasons) }
        public static var reasonUntilOff: String { tr("keepawake.status.untilOff", "until you turn it off") }
        public static func reasonUntil(_ time: String) -> String { format("keepawake.status.until", "until %@", time) }
        public static func reasonAppRunning(_ app: String) -> String { format("keepawake.status.appRunning", "while %@ is running", app) }
        public static func reasonAppsRunning(_ apps: String) -> String { format("keepawake.status.appsRunning", "while %@ are running", apps) }
        public static func reasons(_ first: String, _ second: String) -> String { format("keepawake.status.reasons", "%@ and %@", first, second) }

        // Settings
        public static var status: String { tr("keepawake.settings.status", "Status") }
        public static var forMenu: String { tr("keepawake.settings.for", "For…") }
        public static var stop: String { tr("keepawake.settings.stop", "Stop") }
        public static var keepDisplayOn: String { tr("keepawake.settings.keepDisplayOn", "Keep the display on too") }
        public static var appsSection: String { tr("keepawake.settings.appsSection", "Also keep awake while these apps run") }
        public static var noApps: String { tr("keepawake.settings.noApps", "No apps yet. Add an app to stay awake while it's running.") }
        public static var unnamedApp: String { tr("keepawake.settings.unnamedApp", "App") }

        // Menu bar
        public static var clickHint: String { tr("keepawake.quick.clickHint", "turn on or off") }
        public static func detailUntil(_ time: String) -> String { format("keepawake.quick.detailUntil", "until %@", time) }
        public static var detailOn: String { tr("keepawake.quick.detailOn", "on") }
        public static func headerOnUntil(_ time: String) -> String { format("keepawake.menu.onUntil", "On, until %@", time) }
        public static var headerOnUntilOff: String { tr("keepawake.menu.onUntilOff", "On, until turned off") }
        public static var turnOff: String { tr("keepawake.menu.turnOff", "Turn Off") }
        public static func forDuration(_ duration: String) -> String { format("keepawake.menu.for", "For %@", duration) }
        public static var untilTurnedOff: String { tr("keepawake.menu.untilTurnedOff", "Until Turned Off") }
        public static var keepDisplayOnMenu: String { tr("keepawake.menu.keepDisplayOn", "Keep the Display On") }

        // Erase
        public static func eraseDescription(_ count: Int) -> String {
            plural("keepawake.erase.description", one: "the %lld app in Keep Awake's list", other: "the %lld apps in Keep Awake's list", count)
        }
    }

    /// Lock Keyboard (feature id `keyboardclean`).
    enum LockKeyboard {
        public static var displayName: String { tr("lockkeyboard.displayName", "Lock Keyboard") }
        public static var summary: String { tr("lockkeyboard.summary", "Locks the keyboard so you can wipe it. Unlock with the mouse.") }
        public static var hotkey: String { tr("lockkeyboard.hotkey.start", "Lock keyboard now") }
        public static var command: String { tr("lockkeyboard.command.start", "Lock Keyboard for Cleaning") }
        public static var lockNow: String { tr("lockkeyboard.lockNow", "Lock Keyboard Now") }

        // Notices
        public static var unlockedStopped: String { tr("lockkeyboard.notice.unlockedStopped", "Keyboard unlocked: macOS stopped the lock") }
        public static var unlockedTimeLimit: String { tr("lockkeyboard.notice.unlockedTimeLimit", "Keyboard unlocked (time limit)") }
        public static var unlocked: String { tr("lockkeyboard.notice.unlocked", "Keyboard unlocked") }
        public static var couldNotLock: String {
            tr("lockkeyboard.notice.couldNotLock", "Couldn't lock the keyboard. Check that Omni has the Accessibility permission.")
        }

        // Overlay
        public static var overlayTitle: String { tr("lockkeyboard.overlay.title", "Keyboard locked for cleaning") }
        public static func unlocksIn(_ remaining: String) -> String {
            format("lockkeyboard.overlay.unlocksIn", "Unlocks automatically in %@", remaining)
        }
        public static var unlockButton: String { tr("lockkeyboard.overlay.unlock", "Unlock Keyboard") }
        public static var overlayHelp: String { tr("lockkeyboard.overlay.help", "Click with your mouse or trackpad to unlock.") }

        // Settings and menu
        public static var unlockAfter: String { tr("lockkeyboard.settings.unlockAfter", "Unlock automatically after") }
        public static var unlockAfterMenu: String { tr("lockkeyboard.menu.unlockAfter", "Unlock Automatically After") }
        public static func seconds(_ count: Int) -> String { plural("lockkeyboard.duration.seconds", one: "%lld second", other: "%lld seconds", count) }
        public static func minutes(_ count: Int) -> String { plural("lockkeyboard.duration.minutes", one: "%lld minute", other: "%lld minutes", count) }
        public static var help: String {
            tr("lockkeyboard.settings.help", "All keys, including media and brightness keys, are blocked. The power button and Touch ID can't be blocked. Click Unlock with the mouse, or wait for the time limit. If macOS stops the lock for any reason, the keyboard works again immediately.")
        }
        public static var clickHint: String { tr("lockkeyboard.quick.clickHint", "lock now") }
    }
}
