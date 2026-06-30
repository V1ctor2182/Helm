import Foundation

/// `/healthz` payload from the Helm backend.
public struct Health: Codable, Sendable, Equatable {
    public let status: String
    public let version: String

    public init(status: String, version: String) {
        self.status = status
        self.version = version
    }
}

/// Connection state to the Helm backend, surfaced as the notch status dot.
public enum ConnectionState: Sendable, Equatable {
    case unknown
    case connected(version: String)
    case disconnected
}

/// What a notch quick-capture turns into in Helm (the Journal cluster).
public enum CaptureKind: String, Sendable, CaseIterable, Identifiable {
    case note     // 速记 → /api/notes kind=note
    case journal  // 日记 → /api/notes kind=journal (today)
    case task     // 任务 → /api/tasks (default daily schedule)
    case focus    // 专注 → forward timer; records to /api/focus on stop

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .note: "速记"
        case .journal: "日记"
        case .task: "任务"
        case .focus: "专注"
        }
    }
}

/// Where a task capture goes (HTML `S.taskTo`): the user's own task list, or
/// handed to an agent in the Cockpit.
public enum TaskTarget: String, Sendable, CaseIterable, Identifiable {
    case me      // 给自己 → /api/tasks
    case agent   // 交给 agent → Cockpit

    public var id: String { rawValue }
    public var label: String { self == .me ? "给自己" : "交给 agent" }
}

/// An agent run as reported by `/api/orchestration/runs` (extra fields in the
/// payload are ignored). Drives the notch's agent monitor.
public struct AgentRun: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let agent: String
    public let status: String
    public let prompt: String?

    public init(id: Int, agent: String, status: String, prompt: String?) {
        self.id = id
        self.agent = agent
        self.status = status
        self.prompt = prompt
    }

    /// Running or blocked on the user — i.e. worth surfacing on the notch.
    public var isActive: Bool {
        status == "running" || status == "waiting_permission"
    }

    /// Blocked waiting for a permission decision (needs the user).
    public var needsAttention: Bool {
        status == "waiting_permission"
    }
}

/// A calendar event from `/api/calendar/events` (m2). `when` is a short
/// display string ("All-day" / "10:00–10:30") computed at decode time.
public struct CalEvent: Sendable, Equatable, Identifiable {
    public let id: String
    public let summary: String
    public let when: String

    public init(id: String, summary: String, when: String) {
        self.id = id
        self.summary = summary
        self.when = when
    }
}

/// A near-term event surfaced as the notch's reminder banner (HTML `S.remind`).
public struct EventReminder: Sendable, Equatable, Identifiable {
    public let id: String       // the event id
    public let title: String
    public let timeRange: String  // "10:00–10:30"

    public init(id: String, title: String, timeRange: String) {
        self.id = id
        self.title = title
        self.timeRange = timeRange
    }
}

/// Lifecycle of one capture submission, for inline UI feedback.
public enum CaptureStatus: Sendable, Equatable {
    case idle
    case sending
    case sent
    case failed
}

public enum HelmError: Error, Equatable {
    case badStatus(Int)
}
