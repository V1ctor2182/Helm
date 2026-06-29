import AppKit
import HelmNotchCore
import SwiftUI

/// Borderless panel that can still become key — required so the capture
/// `TextField` accepts keyboard input when the notch is expanded. A plain
/// borderless `NSPanel` refuses key status by default.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Hosting view for the notch. The window is a fixed full-size canvas (so the
/// open/close animation is pure SwiftUI — never an AppKit window resize), but
/// when collapsed only the top slot strip should catch the mouse; everything
/// below is transparent and must click through to whatever's underneath.
final class NotchHostingView: NSHostingView<NotchView> {
    /// Interactive region (centered, from the top edge): the collapsed bar when
    /// closed, the panel when open. Everything outside clicks through.
    var activeSize: () -> CGSize = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        guard hit != nil else { return nil }
        let local = convert(point, from: superview)
        let size = activeSize()
        let x0 = (bounds.width - size.width) / 2
        // NSHostingView is flipped (origin top-left), so distance-from-top is
        // local.y directly; guard the non-flipped case too.
        let fromTop = isFlipped ? local.y : (bounds.height - local.y)
        let inside = local.x >= x0 && local.x <= x0 + size.width && fromTop >= 0 && fromTop <= size.height
        return inside ? hit : nil
    }

    required init(rootView: NotchView) { super.init(rootView: rootView) }
    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }
}
