import AppKit
import HelmNotchCore
import Observation
import SwiftUI

/// Creates the borderless panel pinned to the top-center (notch) of the main
/// screen, hosts the SwiftUI `NotchView`, polls the backend, and grows/shrinks
/// the panel as the model expands into the capture form.
///
/// The full notch shape, click-through, hover-expand and multi-display handling
/// (the boring.notch techniques) land in later milestones.
@MainActor
final class NotchController {
    private let model: NotchModel
    private var panel: NotchPanel?
    private var pollTask: Task<Void, Never>?

    private let collapsedSize = NSSize(width: 220, height: 32)
    private let expandedSize = NSSize(width: 340, height: 284)

    init(model: NotchModel) {
        self.model = model
    }

    func start() {
        let panel = makePanel()
        self.panel = panel
        applyExpansion()  // initial position + size
        panel.orderFrontRegardless()

        pollTask = Task { [model] in
            while !Task.isCancelled {
                await model.poll()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        observeExpansion()

        // Collapse when the user clicks away (panel loses key focus).
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak model] _ in
            MainActor.assumeIsolated { model?.collapse() }
        }
    }

    deinit {
        pollTask?.cancel()
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: collapsedSize),
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

    /// Re-arm an Observation tracker so panel size follows `model.expanded`.
    private func observeExpansion() {
        withObservationTracking {
            _ = model.expanded
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyExpansion()
                self.observeExpansion()
            }
        }
    }

    /// Size the panel for the current state, keeping the top edge pinned to the
    /// screen top and horizontally centered (grows downward from the notch).
    private func applyExpansion() {
        guard let panel else { return }
        let size = model.expanded ? expandedSize : collapsedSize
        guard let screen = NSScreen.main else { return }
        let topY = screen.frame.maxY
        let origin = NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: topY - size.height
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
        if model.expanded {
            panel.makeKeyAndOrderFront(nil)
        }
    }
}
