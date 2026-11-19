import Foundation

/// Copies or moves dropped files into a folder. Never overwrites: a name
/// that's taken gets a number ("Report 2.pdf").
public enum FileTransfer {
    public struct Result: Equatable, Sendable {
        public var done: [URL] = []
        /// Files already in that folder (moving them there does nothing).
        public var skipped: [URL] = []
        public var failed: [URL] = []
    }

    public static func transfer(
        _ sources: [URL], to folder: URL, mode: RingItem.FolderMode, fileManager: FileManager = .default
    ) -> Result {
        var result = Result()
        for source in sources {
            if source.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL, mode == .move {
                result.skipped.append(source)
                continue
            }
            // A folder can't go inside itself.
            if folder.standardizedFileURL.path.hasPrefix(source.standardizedFileURL.path + "/") {
                result.failed.append(source)
                continue
            }
            let target = uniqueDestination(for: source.lastPathComponent, in: folder, fileManager: fileManager)
            do {
                switch mode {
                case .copy: try fileManager.copyItem(at: source, to: target)
                case .move: try fileManager.moveItem(at: source, to: target)
                }
                result.done.append(target)
            } catch {
                result.failed.append(source)
            }
        }
        return result
    }

    /// `name` in `folder`, or "name 2", "name 3"… if taken.
    public static func uniqueDestination(for name: String, in folder: URL, fileManager: FileManager = .default) -> URL {
        let first = folder.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: first.path) else { return first }
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        for number in 2... {
            let candidate = folder.appendingPathComponent(ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return first
    }
}
