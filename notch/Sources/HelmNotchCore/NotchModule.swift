import Foundation

/// The notch's top-level modules — NOMI 稿(`helm-notch-nomi.html` mtabs)的五钮
/// dock:总览/速记/日历/智能体/暂存。`media` 不入 dock,从总览媒体卡 zoom 进入;
/// 剪贴板并入暂存页;专注并入速记 kind(旧 clipboard/dev 模块自此退役)。
public enum NotchModule: String, Sendable, CaseIterable, Identifiable {
    case dashboard
    case capture
    case calendar
    case agents
    case files
    case media

    public var id: String { rawValue }

    /// Modules shown in the dock, left→right (HTML mtabs order). `media` is
    /// omitted — it is a zoom target, not a docked module.
    public static let dock: [NotchModule] = [.dashboard, .capture, .calendar, .agents, .files]

    /// SF Symbol for the round dock button(对应设计稿 stroke 图标,单色无 emoji)。
    public var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .capture: "pencil"
        case .calendar: "calendar"
        case .agents: "terminal"
        case .files: "tray.and.arrow.down"
        case .media: "music.note"
        }
    }

    /// Human label (HTML mtab title)。
    public var title: String {
        switch self {
        case .dashboard: "总览"
        case .capture: "速记"
        case .calendar: "日历"
        case .agents: "智能体"
        case .files: "暂存"
        case .media: "媒体"
        }
    }
}

/// 智能体模块的三张上下滑子页(HTML .swipe/.spage):会话/端口/PR。
/// 上下滑 snap 翻页 + 右缘 sdots 在 B9 落地;枚举随 B3 模块重组先就位。
public enum AgentPage: String, Sendable, CaseIterable, Identifiable {
    case sessions
    case ports
    case prs

    public var id: String { rawValue }

    /// Section label (HTML .subh b)。
    public var title: String {
        switch self {
        case .sessions: "会话"
        case .ports: "本地端口"
        case .prs: "PR · COMMIT 监听"
        }
    }
}
