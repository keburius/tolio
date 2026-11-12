// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OmniCore", targets: ["OmniCore"]),
        .library(name: "OmniPlatform", targets: ["OmniPlatform"]),
        .library(name: "FeatureDiagnostics", targets: ["FeatureDiagnostics"]),
        .library(name: "FeaturePalette", targets: ["FeaturePalette"]),
        .library(name: "FeatureClipboard", targets: ["FeatureClipboard"]),
        .library(name: "FeatureWindows", targets: ["FeatureWindows"]),
        .library(name: "FeatureSwitcher", targets: ["FeatureSwitcher"]),
        .library(name: "FeatureKeepAwake", targets: ["FeatureKeepAwake"]),
        .library(name: "FeatureKeyboardClean", targets: ["FeatureKeyboardClean"]),
        .library(name: "FeatureSystemStats", targets: ["FeatureSystemStats"]),
        .library(name: "FeatureShortcutOverlay", targets: ["FeatureShortcutOverlay"]),
        .library(name: "FeatureTextActions", targets: ["FeatureTextActions"]),
        .library(name: "FeatureScreenshots", targets: ["FeatureScreenshots"]),
    ],
    dependencies: [
        // Approved dependency (SQLite), vendored at 7.12.0. See Vendor/README.md.
        .package(path: "../Vendor/GRDB"),
    ],
    targets: [
        .target(name: "OmniCore"),
        .target(name: "OmniPlatform", dependencies: ["OmniCore"]),
        .target(name: "FeatureDiagnostics", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeaturePalette", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureClipboard", dependencies: [
            "OmniCore", "OmniPlatform", .product(name: "GRDB", package: "GRDB"),
        ]),
        .target(name: "FeatureWindows", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureSwitcher", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureKeepAwake", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureKeyboardClean", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureSystemStats", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureShortcutOverlay", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureTextActions", dependencies: ["OmniCore", "OmniPlatform"]),
        .target(name: "FeatureScreenshots", dependencies: ["OmniCore", "OmniPlatform"]),
        .testTarget(name: "OmniCoreTests", dependencies: ["OmniCore"]),
        .testTarget(name: "OmniPlatformTests", dependencies: ["OmniPlatform"]),
        .testTarget(name: "FeaturePaletteTests", dependencies: ["FeaturePalette", "OmniCore"]),
        .testTarget(name: "FeatureClipboardTests", dependencies: ["FeatureClipboard", "OmniCore", "OmniPlatform"]),
        .testTarget(name: "FeatureWindowsTests", dependencies: ["FeatureWindows", "OmniCore"]),
        .testTarget(name: "FeatureSwitcherTests", dependencies: ["FeatureSwitcher", "OmniCore"]),
        .testTarget(name: "FeatureKeepAwakeTests", dependencies: ["FeatureKeepAwake", "OmniCore", "OmniPlatform"]),
        .testTarget(name: "FeatureKeyboardCleanTests", dependencies: ["FeatureKeyboardClean", "OmniCore", "OmniPlatform"]),
        .testTarget(name: "FeatureSystemStatsTests", dependencies: ["FeatureSystemStats", "OmniCore", "OmniPlatform"]),
        .testTarget(name: "FeatureShortcutOverlayTests", dependencies: ["FeatureShortcutOverlay", "OmniCore"]),
        .testTarget(name: "FeatureTextActionsTests", dependencies: ["FeatureTextActions", "OmniCore", "OmniPlatform"]),
        .testTarget(name: "FeatureScreenshotsTests", dependencies: ["FeatureScreenshots", "OmniCore"]),
    ]
)
