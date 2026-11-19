import Foundation

public extension L10n {
    /// System Stats.
    enum Stats {
        public static var name: String { tr("stats.name", "System Stats") }
        public static var summary: String { tr("stats.summary", "Shows CPU, memory, network and battery in the menu bar.") }

        public static var cpu: String { tr("stats.item.cpu", "CPU") }
        public static var memory: String { tr("stats.item.memory", "Memory") }
        public static var disk: String { tr("stats.item.disk", "Disk") }
        public static var network: String { tr("stats.item.network", "Network") }
        public static var battery: String { tr("stats.item.battery", "Battery") }

        // Menu bar text (short).
        public static func menuCPU(_ value: String) -> String { format("stats.menu.cpu", "CPU %@", value) }
        public static func menuMemory(_ value: String) -> String { format("stats.menu.memory", "MEM %@", value) }
        public static func menuDisk(_ value: String) -> String { format("stats.menu.disk", "Disk %@ free", value) }

        // One-line summary for the control panel.
        public static func lineCPU(_ value: String) -> String { format("stats.line.cpu", "CPU %@", value) }
        public static func lineMemory(_ value: String) -> String { format("stats.line.memory", "Memory %@", value) }
        public static func lineDisk(_ value: String) -> String { format("stats.line.disk", "Disk %@ free", value) }
        public static func lineBattery(_ value: String) -> String { format("stats.line.battery", "Battery %@", value) }

        // Details popover.
        public static var startupDisk: String { tr("stats.detail.startupDisk", "Disk (startup)") }
        public static func usedOf(_ used: String, _ total: String) -> String {
            format("stats.detail.usedOf", "%@ of %@", used, total)
        }
        public static func freeOf(_ free: String, _ total: String) -> String {
            format("stats.detail.freeOf", "%@ free of %@", free, total)
        }
        public static var charging: String { tr("stats.battery.charging", "Charging") }
        public static var onAdapter: String { tr("stats.battery.onAdapter", "On power adapter") }
        public static var onBattery: String { tr("stats.battery.onBattery", "On battery") }
        public static func toFull(_ time: String) -> String { format("stats.battery.toFull", "%@ to full", time) }
        public static func left(_ time: String) -> String { format("stats.battery.left", "%@ left", time) }
        public static var noTemperatures: String {
            tr("stats.detail.noTemperatures", "Temperatures and fans aren't shown: Apple silicon Macs don't offer a reliable way to read them.")
        }

        // Settings.
        public static var showInMenuBar: String { tr("stats.settings.showInMenuBar", "Show in the menu bar") }
        public static var nothingSelectedHelp: String {
            tr("stats.settings.nothingSelectedHelp", "With nothing selected, the menu bar shows an icon. Click it for details.")
        }
        public static var refreshEvery: String { tr("stats.settings.refreshEvery", "Refresh every") }
        public static func seconds(_ count: Int) -> String {
            plural("stats.settings.seconds", one: "%lld second", other: "%lld seconds", count)
        }
        public static var refreshHelp: String {
            tr("stats.settings.refreshHelp", "A longer interval saves battery: about 1.7% CPU at 2 seconds, 0.7% at 5 seconds, 0.2% with only the icon. Temperatures and fan speeds are left out on purpose; on Apple silicon Macs they can't be read reliably.")
        }
        public static var heroLabel: String {
            tr("stats.hero", "Example: CPU, memory and network numbers in the menu bar, with a small chart")
        }
        public static var heroCPU: String { tr("stats.hero.cpu", "CPU") }
        public static var heroMemory: String { tr("stats.hero.memory", "MEM") }
        public static var heroNetwork: String { tr("stats.hero.network", "NET") }
    }

    /// Shortcut Cheat Sheet (feature ID `shortcuts`).
    enum Cheatsheet {
        public static var name: String { tr("cheatsheet.name", "Shortcut Cheat Sheet") }
        public static var summary: String {
            tr("cheatsheet.summary", "Press ⌘ twice and hold to see the shortcuts of the app you're in.")
        }
        public static var showTitle: String { tr("cheatsheet.show", "Show Shortcut Cheat Sheet") }
        public static var showSubtitle: String { tr("cheatsheet.show.subtitle", "For the app you're in") }
        /// Gesture text, e.g. "⌘ ⌘ hold".
        public static func gesture(_ key: String) -> String { format("cheatsheet.gesture", "%@ %@ hold", key, key) }
        public static var appFallback: String { tr("cheatsheet.appFallback", "App") }
        public static var untitledMenu: String { tr("cheatsheet.untitledMenu", "Menu") }

        public static var noApp: String { tr("cheatsheet.noApp", "No app to show shortcuts for") }
        public static func unavailable(_ item: String) -> String {
            format("cheatsheet.itemUnavailable", "“%@” isn't available right now", item)
        }
        public static func unavailableHelp(_ item: String) -> String {
            format("cheatsheet.itemUnavailableHelp", "%@ (not available right now)", item)
        }
        public static func couldNotRun(_ item: String) -> String { format("cheatsheet.couldNotRun", "Couldn't run “%@”", item) }
        public static var truncated: String { tr("cheatsheet.truncated", "Menus are very large, so only the first items are shown") }
        public static var filter: String { tr("cheatsheet.filter", "Filter") }
        public static var clickToRun: String { tr("cheatsheet.clickToRun", "Click an item to run it") }
        public static var reading: String { tr("cheatsheet.reading", "Reading menus…") }
        public static func menusUnreadable(_ app: String) -> String {
            format("cheatsheet.menusUnreadable", "%@ doesn't let other apps read its menus.", app)
        }
        public static func noShortcuts(_ app: String) -> String {
            format("cheatsheet.noShortcuts", "No keyboard shortcuts in %@'s menus.", app)
        }

        // Trigger choices.
        public static var triggerCommand: String { tr("cheatsheet.trigger.command", "Press ⌘ twice and hold") }
        public static var triggerOption: String { tr("cheatsheet.trigger.option", "Press ⌥ twice and hold") }
        public static var triggerControl: String { tr("cheatsheet.trigger.control", "Press ⌃ twice and hold") }
        public static var triggerOff: String { tr("cheatsheet.trigger.off", "Off (use the shortcut)") }

        // Settings.
        public static var openWith: String { tr("cheatsheet.settings.openWith", "Open with") }
        public static var openWithHelp: String {
            tr("cheatsheet.settings.openWithHelp", "Press the key twice and keep holding it; the cheat sheet stays open while you hold. Click an item to run it. Opened with its shortcut, it stays open with a filter field until you press Esc.")
        }
        public static var includeDisabled: String {
            tr("cheatsheet.settings.includeDisabled", "Show items that are unavailable right now")
        }
        public static var includeDisabledNote: String { tr("cheatsheet.settings.includeDisabledNote", "They appear dimmed.") }
        public static var heroLabel: String { tr("cheatsheet.hero", "Example: a sheet listing an app's menu shortcuts") }
        public static var sourceHelp: String {
            tr("cheatsheet.settings.sourceHelp", "Shortcuts come from the app's menu bar. Shortcuts that only work inside a window, and aren't in a menu, can't be listed.")
        }
        public static var cannotWatchKeys: String {
            tr("cheatsheet.settings.cannotWatchKeys", "All Set can't detect key presses right now. Check that All Set is allowed under Accessibility in System Settings.")
        }
    }

    /// Diagnostics (hidden unless ⌥ is held while Settings opens).
    enum Diagnostics {
        public static var name: String { tr("diagnostics.name", "Diagnostics") }
        public static var summary: String {
            tr("diagnostics.summary", "A test shortcut that checks All Set's shortcuts work in every app.")
        }
        public static var testShortcut: String { tr("diagnostics.testShortcut", "Test shortcut") }
        public static var testOmni: String { tr("diagnostics.testOmni", "Test All Set") }
        public static var testOmniSubtitle: String { tr("diagnostics.testOmni.subtitle", "Show the test notice") }
        public static var fired: String { tr("diagnostics.fired", "Test shortcut works") }
        public static var timesFired: String { tr("diagnostics.timesFired", "Times pressed") }
        public static var lastFired: String { tr("diagnostics.lastFired", "Last pressed") }
        public static var never: String { tr("diagnostics.never", "Never") }
        public static var help: String {
            tr("diagnostics.help", "Press the test shortcut (see Shortcuts) in any app. A notice appears and the count goes up.")
        }
    }
}
