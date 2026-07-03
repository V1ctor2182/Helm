// swift-tools-version:5.9
// Helm 桌面壳(用户 2026-07-03 拍板 Swift+WKWebView,见 platform-shell room):
// 独立于 notch/ 的最小 SwiftPM 包——壳只做启动器+窗户,web UI 与后端零改动。
import PackageDescription

let package = Package(
    name: "HelmShell",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "HelmShell", path: "Sources/HelmShell")
    ]
)
