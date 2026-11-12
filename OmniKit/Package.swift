// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OmniCore", targets: ["OmniCore"]),
        .library(name: "OmniPlatform", targets: ["OmniPlatform"]),
        .library(name: "FeatureDiagnostics", targets: ["FeatureDiagnostics"]),
    ],
    targets: [
        .target(name: "OmniCore"),
        .target(name: "OmniPlatform", dependencies: ["OmniCore"]),
        .target(name: "FeatureDiagnostics", dependencies: ["OmniCore", "OmniPlatform"]),
        .testTarget(name: "OmniCoreTests", dependencies: ["OmniCore"]),
        .testTarget(name: "OmniPlatformTests", dependencies: ["OmniPlatform"]),
    ]
)
