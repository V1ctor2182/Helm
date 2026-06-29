import SwiftUI

/// Process entry. Launched as `HelmNotch --hook helm-notch` by Claude Code it runs
/// the lightweight hook relay (no AppKit); otherwise it's the menu-bar app.
@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--hook") {
            HookRunner.run()  // never returns
        }
        HelmNotchApp.main()
    }
}

/// SwiftUI app. No normal window — the notch panel is an NSPanel created by the
/// AppDelegate. Runs as a menu-bar accessory.
struct HelmNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
