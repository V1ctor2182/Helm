import AppKit
import HelmNotchCore
import SwiftUI

extension Color {
    /// Bridge the core's AppKit-free `RGB` into a SwiftUI `Color`.
    init(_ rgb: RGB) {
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

extension NSColor {
    /// Bridge the core's `RGB` into an `NSColor`(NSTextView 富文本编辑器用)。
    convenience init(_ rgb: RGB) {
        self.init(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
    }
}
