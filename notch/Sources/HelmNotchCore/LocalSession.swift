import Foundation

/// A locally-watched Claude Code session (driven by hook events over the bridge),
/// the data behind the notch's 本机 agent cell.
public struct LocalSession: Identifiable, Sendable, Equatable {
    public enum Phase: String, Sendable {
        case running
        case waitingPermission
        case ended
    }

    public let id: String          // Claude session_id
    public var cwd: String
    public var phase: Phase
    public var activity: String?   // what it's doing now (e.g. "Bash: npm i")
    public var pendingTool: String?
    public var pendingDetail: String?
    public var updatedAt: Date

    public init(id: String, cwd: String, phase: Phase, activity: String? = nil,
                pendingTool: String? = nil, pendingDetail: String? = nil, updatedAt: Date) {
        self.id = id
        self.cwd = cwd
        self.phase = phase
        self.activity = activity
        self.pendingTool = pendingTool
        self.pendingDetail = pendingDetail
        self.updatedAt = updatedAt
    }

    /// Last path component of the working directory — the human label.
    public var folderName: String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    public var needsAttention: Bool { phase == .waitingPermission }
    public var isActive: Bool { phase == .running || phase == .waitingPermission }
}
