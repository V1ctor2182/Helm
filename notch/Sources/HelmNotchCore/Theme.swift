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
