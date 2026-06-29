import HelmNotchCore
import SwiftUI

extension Color {
    /// Bridge the core's AppKit-free `RGB` into a SwiftUI `Color`.
    init(_ rgb: RGB) {
        self.init(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
