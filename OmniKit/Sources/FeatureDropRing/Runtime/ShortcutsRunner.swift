import Foundation
import OmniCore

/// Lists and runs Shortcuts with Apple's `shortcuts` command-line tool.
enum ShortcutsRunner {
    static let tool = URL(fileURLWithPath: "/usr/bin/shortcuts")

    /// Names of the user's shortcuts (empty if the tool is missing).
    static func list() async -> [String] {
        await Task.detached(priority: .userInitiated) {
            guard let output = run(["list"]) else { return [] }
            return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }.sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        }.value
    }

    /// Runs `name`, with `inputs` as input files if any. Doesn't wait.
    static func run(_ name: String, inputs: [URL]) {
        let process = Process()
        process.executableURL = tool
        process.arguments = ["run", name] + inputs.flatMap { ["--input-path", $0.path] }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            Log.logger("dropring").error("Couldn't start the shortcuts tool: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = tool
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
