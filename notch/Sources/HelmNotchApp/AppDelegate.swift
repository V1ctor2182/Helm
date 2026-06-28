import AppKit
import HelmNotchCore

/// Owns the notch controller and a menu-bar item for the app's lifetime. Sets
/// accessory activation policy (no Dock icon) — the panel lives in the notch,
/// and the menu-bar item provides the only Quit affordance.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenuBarItem()

        let model = NotchModel(
            backend: HelmClient(baseURL: HelmClient.defaultBaseURL()),
            media: SystemMediaController()
        )
        let controller = NotchController(model: model)
        controller.start()
        self.controller = controller
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Helm Notch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Helm Notch", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出 Helm Notch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        item.menu = menu
        self.statusItem = item
    }
}
