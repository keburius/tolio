import os

/// Factory for `os.Logger` instances under the app's subsystem.
///
/// Privacy rule: never interpolate clipboard contents, selected text, or typed
/// keystrokes into a log message. Log sizes, types, and counts instead.
public enum Log {
    public static let subsystem = "com.george.omni"

    /// Returns a logger for one category, e.g. a feature id or a service name.
    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
