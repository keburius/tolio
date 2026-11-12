import Foundation
@testable import FeaturePalette
import Testing

struct AppScannerTests {
    private func makeApp(_ dir: URL, _ name: String, bundleID: String?) throws {
        let contents = dir.appendingPathComponent("\(name).app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        var info: [String: Any] = ["CFBundleName": name]
        if let bundleID { info["CFBundleIdentifier"] = bundleID }
        (info as NSDictionary).write(to: contents.appendingPathComponent("Info.plist"), atomically: true)
    }

    private func tempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("apps-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func findsAppsInRootsAndSubfolders() throws {
        let root = try tempDir()
        try makeApp(root, "Alpha", bundleID: "com.test.alpha")
        try makeApp(root.appendingPathComponent("Utilities"), "Beta", bundleID: "com.test.beta")
        try makeApp(root.appendingPathComponent("a/b/c"), "TooDeep", bundleID: "com.test.deep")
        let names = AppScanner.scan(roots: [root]).map(\.name)
        #expect(names.sorted() == ["Alpha", "Beta"])
    }

    @Test func doesNotDescendIntoBundles() throws {
        let root = try tempDir()
        try makeApp(root, "Host", bundleID: "com.test.host")
        try makeApp(root.appendingPathComponent("Host.app/Contents/Helpers"), "Helper", bundleID: "com.test.helper")
        #expect(AppScanner.scan(roots: [root], maxDepth: 5).map(\.name) == ["Host"])
    }

    @Test func deduplicatesByBundleIDKeepingFirstRoot() throws {
        let first = try tempDir(), second = try tempDir()
        try makeApp(first, "Same", bundleID: "com.test.same")
        try makeApp(second, "Same Copy", bundleID: "com.test.same")
        try makeApp(second, "NoID", bundleID: nil)
        let apps = AppScanner.scan(roots: [first, second])
        #expect(apps.map(\.name).sorted() == ["NoID", "Same"])
        #expect(apps.first { $0.name == "Same" }?.bundleID == "com.test.same")
    }

    @Test func missingRootsAreSkipped() {
        #expect(AppScanner.scan(roots: [URL(fileURLWithPath: "/nonexistent-\(UUID())")]).isEmpty)
    }
}

struct SettingsPaneCatalogTests {
    private func makeExtension(_ dir: URL, _ name: String, id: String, point: String) throws {
        let contents = dir.appendingPathComponent("\(name).appex/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: NSDictionary = [
            "CFBundleIdentifier": id,
            "EXAppExtensionAttributes": ["EXExtensionPointIdentifier": point],
        ]
        info.write(to: contents.appendingPathComponent("Info.plist"), atomically: true)
    }

    @Test func keepsOnlyInstalledSettingsExtensions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ext-\(UUID())")
        try makeExtension(dir, "Bluetooth", id: "com.apple.BluetoothSettings", point: "com.apple.Settings.extension.ui")
        try makeExtension(dir, "Other", id: "com.apple.Sound-Settings.extension", point: "com.apple.something.else")
        let titles = SettingsPaneCatalog.available(in: dir).map(\.title)
        #expect(titles.contains("Bluetooth"))
        #expect(!titles.contains("Sound"))
        #expect(titles.contains("Privacy: Accessibility"))
    }

    @Test func fallsBackToFullListWhenDiscoveryFindsNothing() {
        let panes = SettingsPaneCatalog.available(in: URL(fileURLWithPath: "/nonexistent-\(UUID())"))
        #expect(panes.count == SettingsPaneCatalog.extensionPanes.count + SettingsPaneCatalog.privacyPanes.count)
    }

    @Test func urlsUseSystemPreferencesScheme() {
        for pane in SettingsPaneCatalog.available() {
            #expect(pane.url.scheme == "x-apple.systempreferences")
        }
    }

    @Test func curatedIDsAreUnique() {
        let ids = SettingsPaneCatalog.extensionPanes.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
