import Foundation

/// Output file names, like macOS's own: "Screenshot 2026-11-12 at 17.20.31.png".
public enum FileNaming {
    public enum Kind: Sendable {
        case screenshot, recording

        var prefix: String { self == .screenshot ? "Screenshot" : "Screen Recording" }
        var fileExtension: String { self == .screenshot ? "png" : "mp4" }
    }

    public static func baseName(_ kind: Kind, date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "\(kind.prefix) \(formatter.string(from: date))"
    }

    /// A URL in `folder` that doesn't exist yet: "… (2).png", "… (3).png", …
    public static func uniqueURL(
        in folder: URL, kind: Kind, date: Date, timeZone: TimeZone = .current,
        exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let base = baseName(kind, date: date, timeZone: timeZone)
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(kind.fileExtension)
        var counter = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent("\(base) (\(counter))").appendingPathExtension(kind.fileExtension)
            counter += 1
        }
        return candidate
    }
}
