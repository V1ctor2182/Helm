import AppKit
import HelmNotchCore
import SwiftUI

/// Creates the borderless NSPanel pinned to the top-center (notch) of the main
/// screen, hosts the SwiftUI `NotchView`, and polls the backend.
///
/// m1 is intentionally a simple top-center floating pill — the full notch shape,
/// click-through, hover-expand and multi-display handling (the boring.notch
/// techniques) land in later milestones.
@MainActor
final class NotchController {
    private let model: NotchModel
    private var panel: NSPanel?
    private var pollTask: Task<Void, Never>?

    private let panelSize = NSSize(width: 220, height: 32)

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        let panel = makePanel()
        position(panel)
        panel.orderFrontRegardless()
        self.panel = panel

        pollTask = Task { [model] in
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    deinit {
        pollTask?.cancel()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: NotchView(model: model))
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let x = frame.midX - panelSize.width / 2
        let y = frame.maxY - panelSize.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
