import SwiftUI

/// SwiftUI app entry. No normal window (`Settings` scene) — the notch panel is
/// an NSPanel created by the AppDelegate. Runs as a menu-bar accessory.
@main
struct HelmNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
