import Foundation

/// The notch's top-level modules — ported from the `helm-notch-pro.html` design
/// (`MODULES` + `S.view`). Expanded, the panel shows one module at a time; the
/// dock switches between them and a left/right swipe cycles `dock` order.
///
/// `media` is reached by zooming the Dashboard's now-playing card (HTML
/// `zoomTo('media')`), so it is *not* part of the docked rotation.
///
/// Glyphs are monochrome Unicode (no emoji — project rule [[helm-no-emoji-ui]]),
/// matching the HTML dock characters exactly.
public enum NotchModule: String, Sendable, CaseIterable, Identifiable {
    case dashboard
    case capture
    case calendar
    case dev
    case clipboard
    case media

    public var id: String { rawValue }

    /// Modules shown in the dock, left→right (HTML `MODULES` order). `media` is
    /// omitted — it is a zoom target, not a docked module.
    public static let dock: [NotchModule] = [.dashboard, .capture, .calendar, .dev, .clipboard]

    /// Monochrome dock glyph (HTML `MODULES[].icon`).
    public var glyph: String {
        switch self {
        case .dashboard: "⊞"
        case .capture: "✎"
        case .calendar: "◫"
        case .dev: "⌘"
        case .clipboard: "⧉"
        case .media: "♪"
        }
    }

    /// Human label (HTML `MODULES[].name`).
    public var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .capture: "速记"
        case .calendar: "Calendar"
        case .dev: "Dev"
        case .clipboard: "Clipboard"
        case .media: "Media"
        }
    }
}

/// Dev module sub-sections — a vertical pager (HTML `DEVSECS`). Unlike the dock,
/// vertical paging *clamps* at the ends (no wrap), matching `switchDev`.
public enum DevSection: String, Sendable, CaseIterable, Identifiable {
    case agents
    case ports
    case reviews
    case stats

    public var id: String { rawValue }

    /// Monochrome rail glyph (HTML `DEVSECS[].i`).
    public var glyph: String {
        switch self {
        case .agents: "◉"
        case .ports: "⇄"
        case .reviews: "⎇"
        case .stats: "▤"
        }
    }

    /// Section label (HTML `DEVSECS[].l`).
    public var title: String {
        switch self {
        case .agents: "Agents"
        case .ports: "Ports"
        case .reviews: "Reviews"
        case .stats: "Stats"
        }
    }
}
