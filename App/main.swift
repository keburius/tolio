import AppKit

// Pure AppKit entry point: a menu bar app has no main window or SwiftUI App scene.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
