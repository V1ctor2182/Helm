import AppKit

/// Borderless panel that can still become key — required so the capture
/// `TextField` accepts keyboard input when the notch is expanded. A plain
/// borderless `NSPanel` refuses key status by default.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
