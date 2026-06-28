// swift-tools-version: 6.2
import PackageDescription

// HelmNotch — native macOS notch control panel (companion app), client of the
// Helm FastAPI backend. Core holds testable logic (Helm API client + state);
// App is the AppKit/SwiftUI notch window. See VibeHub Room "notch-panel".
let package = Package(
    name: "HelmNotch",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HelmNotchCore", targets: ["HelmNotchCore"]),
        .executable(name: "HelmNotchApp", targets: ["HelmNotchApp"]),
    ],
    targets: [
        .target(name: "HelmNotchCore"),
        .executableTarget(
            name: "HelmNotchApp",
            dependencies: ["HelmNotchCore"]
        ),
        .testTarget(
            name: "HelmNotchCoreTests",
            dependencies: ["HelmNotchCore"]
        ),
    ]
)
