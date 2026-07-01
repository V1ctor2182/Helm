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
    private nonisolated(unsafe) var keyMonitor: Any?
    private var lastSwitchAt = Date.distantPast
    // One switch per physical swipe: accumulate the delta of the current trackpad
    // gesture and fire once; ignore the rest (incl. momentum) until it ends.
    private var gestureAccumX: CGFloat = 0
    private var gestureAccumY: CGFloat = 0
    private var gestureSwitched = false

    /// Interactive top strip when collapsed (must clear the slot content).
    private let collapsedHeight: CGFloat = 34
    /// Extra canvas height beyond the panel so a taller drag-resize still fits.
    private let canvasSlack: CGFloat = 260

    private let defaults = UserDefaults.standard
    private let widthKey = "notch.expandedWidth"
    // Height is auto per-view (HTML viewHeight); only the width is user-resizable.

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
        installKeyMonitor()

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
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    /// TAB (Shift+TAB) while typing a 速记 cycles the capture kind (HTML keydown Tab).
    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            var consume = false
            MainActor.assumeIsolated { consume = self?.handleKeyDown(event) ?? false }
            return consume ? nil : event
        }
    }

    /// Returns true to consume the event. keyCode 48 = Tab: cycle the 速记 kind
    /// while the capture field is active (not during a running focus timer).
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.keyCode == 48, model.expanded, model.module == .capture,
              model.locked, !model.focusOn else { return false }
        model.cycleCaptureKind(event.modifierFlags.contains(.shift) ? -1 : 1)
        return true
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
        // Note: no `!locked` guard — swiping away while typing 速记 is allowed;
        // setModule() clears the lock so the panel can then collapse on hover-out.
        guard model.expanded, let panel else { return }
        // Only when the pointer is over the visible top-centered shell.
        guard let screen = NSScreen.main else { return }
        let w = CGFloat(model.expandedWidth), h = CGFloat(model.autoExpandedHeight)
        let shell = NSRect(x: screen.frame.midX - w / 2, y: screen.frame.maxY - h, width: w, height: h)
        guard shell.contains(NSEvent.mouseLocation), panel.isVisible else { return }

        // AppKit deltas are inverted vs the web's wheel deltas; flip so
        // swipe-right → next module, swipe-down → next Dev page.
        // TODO(align-gesture): sign may need tuning on real hardware.
        let dx = -event.scrollingDeltaX, dy = -event.scrollingDeltaY

        // Trackpad: one switch per physical swipe. Ignore momentum entirely, and
        // only fire once the accumulated delta crosses a deliberate threshold —
        // this stops a single flick from racing through several modules.
        let isTrackpad = event.phase != [] || event.momentumPhase != []
        if isTrackpad {
            if event.momentumPhase != [] { return }        // ignore inertia tail
            if event.phase.contains(.began) {              // new gesture starts
                gestureAccumX = 0; gestureAccumY = 0; gestureSwitched = false
            }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                gestureSwitched = false; return
            }
            guard !gestureSwitched else { return }         // already switched this swipe
            gestureAccumX += dx; gestureAccumY += dy
            let threshold: CGFloat = 22
            // Cooldown so a new swipe can't interrupt the in-flight slide → snap.
            let cooled = Date().timeIntervalSince(lastSwitchAt) > 0.30
            if model.module == .dev, abs(gestureAccumY) > abs(gestureAccumX), abs(gestureAccumY) > threshold {
                gestureSwitched = true
                if cooled { animatedSwitch { model.switchDev(gestureAccumY > 0 ? 1 : -1) } }
            } else if abs(gestureAccumX) > abs(gestureAccumY), abs(gestureAccumX) > threshold {
                gestureSwitched = true
                if cooled { animatedSwitch { model.switchModule(gestureAccumX > 0 ? 1 : -1) } }
            }
            return
        }

        // Mouse wheel (discrete, no phase): a short cooldown paces the steps.
        guard Date().timeIntervalSince(lastSwitchAt) > 0.30 else { return }
        if model.module == .dev, abs(dy) > abs(dx), abs(dy) > 1 {
            animatedSwitch { model.switchDev(dy > 0 ? 1 : -1) }
        } else if abs(dx) > abs(dy), abs(dx) > 1 {
            animatedSwitch { model.switchModule(dx > 0 ? 1 : -1) }
        }
    }

    /// Run a module/dev switch inside an explicit slide animation — NSEvent
    /// callbacks don't reliably trigger SwiftUI's implicit `.animation(value:)`,
    /// which caused occasional instant "jumps" (device feedback).
    private func animatedSwitch(_ body: () -> Void) {
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.36)) { body() }
        lastSwitchAt = Date()
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
                : CGSize(width: CGFloat(model.notchWidth) + 200, height: collapsedHeight)
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
    }
}
