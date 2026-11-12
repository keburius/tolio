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
        .testTarget(name: "OmniCoreTests", dependencies: ["OmniCore"]),
        .testTarget(name: "OmniPlatformTests", dependencies: ["OmniPlatform"]),
        .testTarget(name: "FeaturePaletteTests", dependencies: ["FeaturePalette", "OmniCore"]),
        .testTarget(name: "FeatureClipboardTests", dependencies: ["FeatureClipboard", "OmniCore"]),
    ]
)
