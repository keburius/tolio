import AppKit
import OmniCore

// First launch after the rename from Omni: bring settings and files across
// before anything reads them.
LegacyDataMigration.runIfNeeded()

// Pure AppKit entry point: a menu bar app has no main window or SwiftUI App scene.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
