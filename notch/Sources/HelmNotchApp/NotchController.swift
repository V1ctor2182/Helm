import AppKit
import HelmNotchCore
import Observation
import SwiftUI

/// Creates the borderless panel pinned to the top-center (notch) of the main
/// screen and hosts the SwiftUI `NotchView`. The window is a *fixed full-size
/// canvas* — it is never resized to open/close (that AppKit resize is what made
/// the animation janky); the open/close grow is pure SwiftUI inside. A custom
/// hit-test (see `NotchHostingView`) makes the transparent area below the
/// collapsed strip click through.
@MainActor
final class NotchController {
    private let model: NotchModel
    private var panel: NotchPanel?
    private var pollTask: Task<Void, Never>?

    /// Trackpad swipe → switch module / page Dev (HTML wheel handler).
    /// `nonisolated(unsafe)`: set only on the MainActor, read once in deinit.
    private nonisolated(unsafe) var scrollMonitor: Any?
    private var lastSwitchAt = Date.distantPast

    /// Interactive top strip when collapsed (must clear the slot content).
    private let collapsedHeight: CGFloat = 34
    /// Extra canvas height beyond the panel so a taller drag-resize still fits.
    private let canvasSlack: CGFloat = 260

    private let defaults = UserDefaults.standard
    private let widthKey = "notch.expandedWidth"
    private let heightKey = "notch.expandedHeight.v2"  // v2: drop the old 300 default

    init(model: NotchModel) {
        self.model = model
    }

    /// The fixed window size: wide/tall enough for the panel (plus drag slack).
    private var canvasSize: NSSize {
        // 640 floor leaves room for the 620-wide permission banner.
        NSSize(width: max(CGFloat(model.expandedWidth), CGFloat(model.notchWidth) + 320, 640),
               height: CGFloat(model.expandedHeight) + canvasSlack)
    }

    func start() {
        if let screen = NSScreen.main {
            model.notchWidth = detectNotchWidth(screen)
        }
        if let w = defaults.object(forKey: widthKey) as? Double { model.expandedWidth = w }
        if let h = defaults.object(forKey: heightKey) as? Double { model.expandedHeight = h }

        let panel = makePanel()
        self.panel = panel

        if ProcessInfo.processInfo.environment["HELM_NOTCH_EXPANDED"] == "1" {
            model.expanded = true
            model.hoverPinned = true
        }
        applyFrame()
        panel.orderFrontRegardless()

        pollTask = Task { [model] in
            while !Task.isCancelled {
                await model.poll()
                try? await Task.sleep(for: .seconds(5))
            }
        }
        observeState()
        installScrollMonitor()

        // The panel only becomes key when the capture field is focused, so losing
        // key = the user clicked away — collapse (keeping any typed text).
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak model] _ in
            MainActor.assumeIsolated { model?.collapse() }
        }
    }

    deinit {
        pollTask?.cancel()
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    }

    /// Map a trackpad two-finger swipe over the expanded panel to a module switch
    /// (horizontal) or a Dev sub-page page (vertical), mirroring the HTML wheel
    /// handler. A short cooldown makes one swipe = one step.
    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            MainActor.assumeIsolated { self?.handleScroll(event) }
            return event
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard model.expanded, !model.locked, let panel else { return }
        // Only when the pointer is over the visible top-centered shell.
        guard let screen = NSScreen.main else { return }
        let w = CGFloat(model.expandedWidth), h = CGFloat(model.autoExpandedHeight)
        let shell = NSRect(x: screen.frame.midX - w / 2, y: screen.frame.maxY - h, width: w, height: h)
        guard shell.contains(NSEvent.mouseLocation), panel.isVisible else { return }

        // One step per gesture: ignore further events within the cooldown.
        let now = Date()
        guard now.timeIntervalSince(lastSwitchAt) > 0.35 else { return }

        // AppKit scrolling deltas are inverted vs the web's wheel deltas; flip so
        // swipe-right → next module, swipe-down → next Dev page.
        // TODO(align-gesture): sign may need tuning on real hardware.
        let dx = -event.scrollingDeltaX, dy = -event.scrollingDeltaY
        if model.module == .dev, abs(dy) > abs(dx), abs(dy) > 6 {
            model.switchDev(dy > 0 ? 1 : -1)
            lastSwitchAt = now
        } else if abs(dx) > abs(dy), abs(dx) > 6 {
            model.switchModule(dx > 0 ? 1 : -1)
            lastSwitchAt = now
        }
    }

    /// Notch width in points: the gap between the two usable menu-bar areas.
    private func detectNotchWidth(_ screen: NSScreen) -> Double {
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea?.maxX,
           let right = screen.auxiliaryTopRightArea?.minX,
           right > left {
            return Double(right - left)
        }
        return 200  // 14"/16" MacBook Pro fallback
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: canvasSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false  // shadow is drawn in SwiftUI on the panel shape
        // Clicking the capture TextField auto-makes the panel key + focuses it,
        // without hover-expand ever stealing focus from the user's app.
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        let host = NotchHostingView(rootView: NotchView(model: model))
        host.activeSize = { [weak model, collapsedHeight] in
            guard let model else { return .zero }
            if model.reminder != nil {
                return CGSize(width: 560, height: 152)  // reminder banner
            }
            if model.localAttentionCount > 0 {
                return CGSize(width: 620, height: 208)  // permission banner
            }
            return model.expanded
                ? CGSize(width: model.expandedWidth, height: model.autoExpandedHeight)
                : CGSize(width: CGFloat(model.notchWidth) + 150, height: collapsedHeight)
        }
        panel.contentView = host
        return panel
    }

    /// Re-arm an Observation tracker so the canvas follows a drag-resize and the
    /// panel grabs key focus only while locked (keyboard input).
    private func observeState() {
        withObservationTracking {
            _ = model.locked
            _ = model.expandedWidth
            _ = model.expandedHeight
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyFrame()
                self.persistSize()
                self.observeState()
            }
        }
    }

    /// Position the fixed canvas: top edge pinned to the screen top, centered so
    /// the collapsed strip lines up with the physical notch.
    private func applyFrame() {
        guard let panel, let screen = NSScreen.main else { return }
        let size = canvasSize
        let origin = NSPoint(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        if model.locked { panel.makeKeyAndOrderFront(nil) } else { panel.orderFrontRegardless() }
    }

    private func persistSize() {
        defaults.set(model.expandedWidth, forKey: widthKey)
        defaults.set(model.expandedHeight, forKey: heightKey)
    }
}
