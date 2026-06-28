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

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .note: "速记"
        case .journal: "日记"
        case .task: "任务"
        }
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
