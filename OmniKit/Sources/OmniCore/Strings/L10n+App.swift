import Foundation

public extension L10n {
    /// The app shell: menu bar, control panel, Settings, onboarding.
    enum App {
        public static var name: String { tr("app.name", "Tolio") }
        public static var openControlPanel: String { tr("app.openControlPanel", "Open Control Panel") }
        public static var openControlPanelAction: String { tr("app.openControlPanel.action", "Open the control panel") }
        public static var settings: String { tr("app.settings", "Settings…") }
        public static var settingsCommand: String { tr("app.settings.command", "Tolio Settings") }
        public static var setupGuide: String { tr("app.setupGuide", "Setup Guide…") }
        public static var setupGuideCommand: String { tr("app.setupGuide.command", "Tolio Setup Guide") }
        public static var about: String { tr("app.about", "About Tolio") }
        public static var quit: String { tr("app.quit", "Quit Tolio") }
        public static var editMenu: String { tr("app.menu.edit", "Edit") }
        public static var undo: String { tr("app.menu.undo", "Undo") }
        public static var redo: String { tr("app.menu.redo", "Redo") }
        public static var cut: String { tr("app.menu.cut", "Cut") }
        public static var copy: String { tr("app.menu.copy", "Copy") }
        public static var paste: String { tr("app.menu.paste", "Paste") }
        public static var selectAll: String { tr("app.menu.selectAll", "Select All") }
        public static var stopRecording: String { tr("app.stopRecording", "Stop recording") }
        public static func recordingTooltip(_ time: String) -> String { format("app.recordingTooltip", "Recording %@. Click to stop.", time) }
        public static func featureIsOff(_ feature: String) -> String { format("app.featureIsOff", "%@ is off.", feature) }
        public static func featureNeedsPermission(_ feature: String, _ permission: String) -> String {
            format("app.featureNeedsPermission", "%@ needs %@ permission.", feature, permission)
        }
        public static func iconTooltip(_ title: String, _ detail: String) -> String { format("app.iconTooltip", "%@: %@", title, detail) }
    }

    enum Panel {
        public static var recentlyCopied: String { tr("panel.recentlyCopied", "Recently copied") }
        public static var showAll: String { tr("panel.showAll", "Show All") }
        public static var windowSection: String { tr("panel.window", "Window") }
        public static func windowTitle(_ app: String, _ title: String) -> String { format("panel.windowTitle", "%@ — “%@”", app, title) }
        public static var noWindow: String { tr("panel.noWindow", "No window to arrange. Click a window, then open the control panel again.") }
        public static var nothingCopied: String { tr("panel.nothingCopied", "Nothing copied yet. Copy something to see it here.") }
        public static func turnOnToSeeClips(_ feature: String) -> String { format("panel.turnOnClips", "Turn on %@ to see what you copied here.", feature) }
        public static func stop(_ time: String) -> String { format("panel.stop", "Stop · %@", time) }
        public static var leftHalf: String { tr("panel.layout.leftHalf", "Left half") }
        public static var rightHalf: String { tr("panel.layout.rightHalf", "Right half") }
        public static var leftThird: String { tr("panel.layout.leftThird", "Left third") }
        public static var centerThird: String { tr("panel.layout.centerThird", "Center third") }
        public static var rightThird: String { tr("panel.layout.rightThird", "Right third") }
        public static var maximize: String { tr("panel.layout.maximize", "Maximize") }
        public static var options: String { tr("panel.options", "Options") }
    }

    enum SettingsUI {
        public static var windowTitle: String { tr("settings.windowTitle", "Tolio Settings") }
        public static var overview: String { tr("settings.page.overview", "Overview") }
        public static var menuBar: String { tr("settings.page.menuBar", "Menu Bar") }
        public static var shortcuts: String { tr("settings.page.shortcuts", "Shortcuts") }
        public static var permissions: String { tr("settings.page.permissions", "Permissions") }
        public static var general: String { tr("settings.page.general", "General") }
        public static var features: String { tr("settings.features", "Features") }
        public static var searchPrompt: String { tr("settings.search", "Search settings") }
        public static func noSettingsMatch(_ query: String) -> String { format("settings.noMatch", "No settings match “%@”.", query) }
        public static func waitingBanner(_ count: Int) -> String {
            plural("settings.waitingBanner", one: "%lld feature is waiting for a permission.", other: "%lld features are waiting for a permission.", count)
        }
        public static func needs(_ feature: String, _ permission: String) -> String { format("settings.needs", "%@ needs %@.", feature, permission) }
        public static func pausedBanner(_ permission: String, _ why: String) -> String {
            format("settings.pausedBanner", "Tolio needs %@ permission. %@ Until then, this feature is paused.", permission, why)
        }
        public static var updatesByItself: String { tr("settings.updatesByItself", "The status updates by itself.") }
        public static var problemTurnOffOn: String { tr("settings.problemTurnOffOn", "Turn it off and on again to retry.") }
        public static var shortcutsSection: String { tr("settings.section.shortcuts", "Shortcuts") }
        public static var settingsSection: String { tr("settings.section.settings", "Settings") }
        public static var permissionsSection: String { tr("settings.section.permissions", "Permissions") }
        public static var resetToDefaults: String { tr("settings.resetToDefaults", "Reset to Defaults…") }
        public static func resetQuestion(_ feature: String) -> String { format("settings.resetQuestion", "Reset %@ settings?", feature) }
        public static var resetExplanation: String {
            tr("settings.resetExplanation", "Options and shortcuts go back to their defaults. Your on/off choice and the things you made are kept.")
        }
        public static var eraseData: String { tr("settings.eraseData", "Erase Data…") }
        public static var erase: String { tr("settings.erase", "Erase") }
        public static func eraseQuestion(_ what: String) -> String { format("settings.eraseQuestion", "Erase %@?", what) }
        public static var cannotUndo: String { tr("settings.cannotUndo", "This can't be undone.") }
        public static var gesture: String { tr("settings.gesture", "gesture") }
        // Menu Bar page
        public static var iconsInMenuBar: String { tr("settings.menuBar.icons", "Icons in the menu bar") }
        public static var separateIcons: String { tr("settings.menuBar.separate", "Separate icons for quick actions") }
        public static var oneIcon: String { tr("settings.menuBar.single", "One icon only: everything is in the control panel") }
        public static var quickActions: String { tr("settings.menuBar.quickActions", "Quick actions") }
        public static var quickActionsHelp: String { tr("settings.menuBar.quickActionsHelp", "Drag to reorder, left to right as in the menu bar. Right-click any icon for its options.") }
        public static func clickDoes(_ hint: String) -> String { format("settings.menuBar.clickDoes", "Click: %@", hint) }
        public static var moveLeft: String { tr("settings.menuBar.moveLeft", "Move Left") }
        public static var moveRight: String { tr("settings.menuBar.moveRight", "Move Right") }
        public static var statsNote: String {
            tr("settings.menuBar.statsNote", "System Stats has its own menu bar item. In one-icon mode its numbers move into the control panel instead.")
        }
        public static var notchNote: String {
            tr("settings.menuBar.notchNote", "On Macs with a notch, macOS hides menu bar icons that don't fit. If an icon is missing, try “One icon only”.")
        }
        // Shortcuts page
        public static var action: String { tr("settings.shortcuts.action", "Action") }
        public static var feature: String { tr("settings.shortcuts.feature", "Feature") }
        public static var shortcut: String { tr("settings.shortcuts.shortcut", "Shortcut") }
        public static var filter: String { tr("settings.shortcuts.filter", "Filter") }
        public static var showAll: String { tr("settings.shortcuts.showAll", "All") }
        public static var showOnOnly: String { tr("settings.shortcuts.onOnly", "Features that are on") }
        public static var gestures: String { tr("settings.shortcuts.gestures", "Gestures") }
        public static func sameAs(_ other: String) -> String { format("settings.shortcuts.sameAs", "Same as “%@”. One of them won't work.", other) }
        public static func sameAsOff(_ other: String) -> String { format("settings.shortcuts.sameAsOff", "Same as “%@”; they'll clash when both are on.", other) }
        public static var usedByAnotherApp: String { tr("settings.shortcuts.usedByAnotherApp", "Used by another app.") }
        public static var featureOffSuffix: String { tr("settings.shortcuts.offSuffix", "(off)") }
        public static var offNote: String { tr("settings.shortcuts.offNote", "Shortcuts for features that are off are shown in gray and can still be changed.") }
        public static var resetAllShortcuts: String { tr("settings.shortcuts.resetAll", "Reset All Shortcuts…") }
        public static var resetAllShortcutsQuestion: String { tr("settings.shortcuts.resetAllQuestion", "Reset all shortcuts to their defaults?") }
        public static func noShortcutsMatch(_ query: String) -> String { format("settings.shortcuts.noMatch", "No shortcuts match “%@”.", query) }
        public static func alreadyUsedBy(_ title: String) -> String { format("settings.shortcuts.alreadyUsed", "Already used by “%@”.", title) }
        public static var refusedByMac: String { tr("settings.shortcuts.refused", "Another app already uses this shortcut.") }
        // General page
        public static var openAtLogin: String { tr("settings.general.openAtLogin", "Open Tolio at login") }
        public static var approveLoginItem: String { tr("settings.general.approveLoginItem", "Approve Tolio in Login Items to finish.") }
        public static var openLoginItems: String { tr("settings.general.openLoginItems", "Open Login Items") }
        public static var openSetupGuide: String { tr("settings.general.openSetupGuide", "Open Setup Guide…") }
        public static var language: String { tr("settings.general.language", "Language") }
        public static var english: String { tr("settings.general.english", "English") }
        public static var languageNote: String { tr("settings.general.languageNote", "More languages can be added later.") }
        public static var version: String { tr("settings.general.version", "Version") }
        public static var resetAllSettings: String { tr("settings.general.resetAll", "Reset All Settings…") }
        public static var resetAllQuestion: String { tr("settings.general.resetAllQuestion", "Reset all settings?") }
        public static var resetAllExplanation: String {
            tr("settings.general.resetAllExplanation", "Every feature's options, all shortcuts and the menu bar layout go back to their defaults. Which features are on and the things you made are kept.")
        }
        public static var diagnostics: String { tr("settings.diagnostics", "Diagnostics") }
    }

    enum Onboarding {
        public static var windowTitle: String { tr("onboarding.windowTitle", "Welcome to Tolio") }
        public static var intro: String {
            tr("onboarding.intro", "Tolio adds the shortcuts your Mac is missing: one menu bar app for screenshots, clipboard history, window layouts, staying awake and quick launching.")
        }
        public static var screenshots: String { tr("onboarding.icon.screenshots", "Screenshots") }
        public static var clipboard: String { tr("onboarding.icon.clipboard", "Clipboard") }
        public static var windows: String { tr("onboarding.icon.windows", "Windows") }
        public static var keepAwake: String { tr("onboarding.icon.keepAwake", "Energy Mode") }
        public static var launcher: String { tr("onboarding.icon.launcher", "Launcher") }
        public static var staysOnMac: String { tr("onboarding.staysOnMac", "Everything stays on this Mac.") }
        public static var getStarted: String { tr("onboarding.getStarted", "Get Started") }
        public static var chooseTitle: String { tr("onboarding.choose.title", "Choose what you want") }
        public static var chooseSubtitle: String { tr("onboarding.choose.subtitle", "Start with our picks or choose your own. You can change this any time in Settings.") }
        public static var recommended: String { tr("onboarding.choose.recommended", "Recommended") }
        public static var everything: String { tr("onboarding.choose.everything", "Everything") }
        public static var more: String { tr("onboarding.choose.more", "More") }
        public static func needs(_ permission: String) -> String { format("onboarding.needs", "needs %@", permission) }
        public static var permissionsTitle: String { tr("onboarding.permissions.title", "Allow what your features need") }
        public static var noPermissions: String { tr("onboarding.permissions.none", "The features you chose don't need any permissions.") }
        public static var optionalSuffix: String { tr("onboarding.permissions.optionalSuffix", "(optional)") }
        public static var skipForNow: String { tr("onboarding.permissions.skip", "Skip for Now") }
        public static var reopenNote: String {
            tr("onboarding.permissions.reopenNote", "Switched it on but it still says “Not allowed”? Some permissions start working after Tolio reopens.")
        }
        public static var reopenOmni: String { tr("onboarding.permissions.reopen", "Reopen Tolio") }
        public static func usedBy(_ list: String) -> String { format("onboarding.permissions.usedBy", "Used by %@", list) }
        public static var doneTitle: String { tr("onboarding.done.title", "You're set. A few shortcuts to remember:") }
        public static var doneNote: String {
            tr("onboarding.done.note", "Only shortcuts for the features you chose are listed. All of them are in Settings → Shortcuts, where you can change them.")
        }
        public static var finish: String { tr("onboarding.finish", "Finish") }
        public static var tryIt: String { tr("onboarding.tryIt", "Try It: Open the Control Panel") }
        public static var orClickIcon: String { tr("onboarding.orClickIcon", "Open the control panel (or click Tolio's menu bar icon)") }
    }
}
