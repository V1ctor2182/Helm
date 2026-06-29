import AppKit
import HelmNotchCore
import SwiftUI

/// Owns the notch controller, the bridge server (local Claude Code monitoring),
/// and a menu-bar item for the app's lifetime. Accessory activation policy (no
/// Dock icon) — the panel lives in the notch.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController?
    private var bridge: BridgeServer?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var model: NotchModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenuBarItem()

        let adapter = AdapterMediaController()
        let media: MediaController = adapter.isAvailable ? adapter : SystemMediaController()
        let model = NotchModel(
            backend: HelmClient(baseURL: HelmClient.defaultBaseURL()),
            media: media)
        self.model = model

        // Local Claude Code monitoring: socket bridge + permission round-trip.
        let bridge = BridgeServer(model: model)
        bridge.start()
        self.bridge = bridge
        model.resolvePermission = { [weak bridge] session, allow in
            bridge?.resolve(session, allow: allow)
        }
        model.openSettings = { [weak self] in self?.showSettings() }

        let controller = NotchController(model: model)
        controller.start()
        self.controller = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        bridge?.stop()
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "Helm Notch")
        let menu = NSMenu()
        menu.addItem(withTitle: "Helm Notch", action: nil, keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "退出 Helm Notch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        item.menu = menu
        self.statusItem = item
    }

    @objc private func showSettings() {
        guard let model else { return }
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 360),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Helm Notch 设置"
            window.contentView = NSHostingView(rootView: SettingsView(model: model))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
