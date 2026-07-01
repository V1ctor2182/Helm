import Foundation

/// A plain RGB triple (0...1 components) so the core stays AppKit/SwiftUI-free
/// and testable; the App target maps this to a SwiftUI `Color`.
public struct RGB: Sendable, Equatable {
    public let r: Double
    public let g: Double
    public let b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    /// Parse `"#FB9E66"` / `"FB9E66"` / `"F96"` into components.
    public init(hex: String) {
        var s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        r = Double((v >> 16) & 0xFF) / 255
        g = Double((v >> 8) & 0xFF) / 255
        b = Double(v & 0xFF) / 255
    }
}

/// The notch's background material (HTML settings `MATS`). Default `.black` keeps
/// the established solid-black aesthetic; glass options blur the wallpaper behind.
public enum NotchMaterial: String, Sendable, CaseIterable, Identifiable {
    case black
    case darkGlass
    case lightGlass
    case vibrant

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .black: "纯黑"
        case .darkGlass: "暗玻璃"
        case .lightGlass: "白玻璃"
        case .vibrant: "彩色玻璃"
        }
    }
}

/// How the accent color is chosen. Default is `.daily` — a new curated color
/// each day (stable within the day, switches at local midnight).
public enum ThemeMode: String, Sendable, CaseIterable, Identifiable {
    case daily   // 每日轮换 — palette[dayIndex % count]
    case hue     // 连续色相 — golden-angle around the wheel, ~365 distinct
    case fixed   // 固定 — a single chosen palette color

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .daily: "每日轮换"
        case .hue: "连续色相"
        case .fixed: "固定颜色"
        }
    }
}

/// Accent-color engine. The palette is hand-tuned to read well on the black
/// notch; status colors (green/orange/red) live elsewhere and never rotate.
public enum Theme {
    public static let palette: [RGB] = [
        RGB(hex: "FB9E66"),  // Peach
        RGB(hex: "FF6F61"),  // Coral
        RGB(hex: "FFC53D"),  // Amber
        RGB(hex: "B6E84F"),  // Lime
        RGB(hex: "34D6C0"),  // Mint
        RGB(hex: "4FD6E8"),  // Aqua
        RGB(hex: "5EA0FF"),  // Sky
        RGB(hex: "7C9CFF"),  // Indigo
        RGB(hex: "B98CFF"),  // Violet
        RGB(hex: "FF6FA5"),  // Rose
    ]

    /// Local-day index (days since the Unix epoch) — the seed that keeps a day's
    /// color stable and flips it at midnight.
    public static func dayIndex(_ date: Date, calendar: Calendar = .current) -> Int {
        Int(calendar.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }

    /// The accent for a given day under a given mode.
    public static func accent(for date: Date, mode: ThemeMode, fixedIndex: Int = 0) -> RGB {
        switch mode {
        case .fixed:
            return palette[wrap(fixedIndex)]
        case .daily:
            return palette[wrap(dayIndex(date))]
        case .hue:
            var h = (Double(dayIndex(date)) * 137.508).truncatingRemainder(dividingBy: 360)
            if h < 0 { h += 360 }
            return hsl(h: h, s: 0.80, l: 0.67)
        }
    }

    private static func wrap(_ i: Int) -> Int {
        ((i % palette.count) + palette.count) % palette.count
    }

    // MARK: Contrast-aware accent (HTML MATS + randomTheme's while-loop)

    /// Each material's "effective background" for contrast math (HTML `MATS[].rep`).
    public static func materialBackground(_ m: NotchMaterial) -> RGB {
        switch m {
        case .black: RGB(r: 12/255, g: 14/255, b: 16/255)
        case .darkGlass: RGB(r: 40/255, g: 44/255, b: 48/255)
        case .lightGlass: RGB(r: 208/255, g: 208/255, b: 214/255)
        case .vibrant: RGB(r: 42/255, g: 46/255, b: 58/255)
        }
    }

    /// WCAG relative luminance (HTML `_lum`).
    static func luminance(_ c: RGB) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    /// WCAG contrast ratio between two colors (HTML `_contrast`).
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let l1 = luminance(a), l2 = luminance(b)
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    /// Nudge `accent` until it reads on the material's background (≥ 3.2:1),
    /// ported 1:1 from HTML `randomTheme`: darken on a light bg, brighten on a
    /// dark bg, up to 8 steps. On black this is a no-op (palette already reads).
    public static func contrastSafeAccent(_ accent: RGB, on material: NotchMaterial) -> RGB {
        let bg = materialBackground(material)
        let bgLight = luminance(bg) > 0.4
        var c = accent
        var tries = 0
        while contrast(c, bg) < 3.2, tries < 8 {
            if bgLight {
                c = RGB(r: c.r * 0.55, g: c.g * 0.55, b: c.b * 0.55)
            } else {
                c = RGB(r: min(1, c.r * 1.2 + 28/255), g: min(1, c.g * 1.2 + 28/255), b: min(1, c.b * 1.2 + 28/255))
            }
            tries += 1
        }
        return c
    }

    /// HSL→RGB (h in degrees, s/l in 0...1).
    static func hsl(h: Double, s: Double, l: Double) -> RGB {
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = l - c / 2
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<60: (r, g, b) = (c, x, 0)
        case ..<120: (r, g, b) = (x, c, 0)
        case ..<180: (r, g, b) = (0, c, x)
        case ..<240: (r, g, b) = (0, x, c)
        case ..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return RGB(r: r + m, g: g + m, b: b + m)
    }
}
