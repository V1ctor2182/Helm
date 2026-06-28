import AppKit
import HelmNotchCore

/// Owns the notch controller for the app's lifetime. Sets accessory activation
/// policy (no Dock icon) — the panel lives in the notch, not the Dock.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = NotchController(model: NotchModel(backend: HelmClient()))
        controller.start()
        self.controller = controller
    }
}
