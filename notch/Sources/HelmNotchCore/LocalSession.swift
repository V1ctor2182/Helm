import Foundation

/// A locally-watched Claude Code session (driven by hook events over the bridge),
/// the data behind the notch's 本机 agent cell.
public struct LocalSession: Identifiable, Sendable, Equatable {
    public enum Phase: String, Sendable {
        case running
        case waitingPermission
        /// Blocked on an AskUserQuestion — answer it right in the notch.
        case waitingQuestion
        /// Turn finished (Stop) but the CLI is still alive waiting for the next
        /// prompt — the session can take a freeform reply (terminal injection).
        case idle
        /// SessionEnd — the CLI is gone; row lingers briefly then prunes.
        case ended
    }

    public let id: String          // Claude session_id
    public var cwd: String
    public var phase: Phase
    public var activity: String?   // what it's doing now (e.g. "Bash: npm i")
    public var pendingTool: String?
    public var pendingDetail: String?
    public var updatedAt: Date

    // Detail-view content (fed by richer hook payloads):
    public var pendingToolInput: String?  // raw tool_input JSON while a request is parked
    public var question: QuestionPrompt?  // parsed AskUserQuestion (waitingQuestion)
    public var lastPrompt: String?        // the user's latest prompt
    public var lastAssistant: String?     // last assistant message (set on Stop)
    public var transcriptPath: String?

    // Terminal identity — lets the notch inject a reply into the右 pane.
    public var termProgram: String?
    public var tmuxPane: String?
    public var tmuxSocket: String?

    public init(id: String, cwd: String, phase: Phase, activity: String? = nil,
                pendingTool: String? = nil, pendingDetail: String? = nil, updatedAt: Date,
                question: QuestionPrompt? = nil, lastPrompt: String? = nil,
                lastAssistant: String? = nil, transcriptPath: String? = nil,
                termProgram: String? = nil, tmuxPane: String? = nil, tmuxSocket: String? = nil) {
        self.id = id
        self.cwd = cwd
        self.phase = phase
        self.activity = activity
        self.pendingTool = pendingTool
        self.pendingDetail = pendingDetail
        self.updatedAt = updatedAt
        self.question = question
        self.lastPrompt = lastPrompt
        self.lastAssistant = lastAssistant
        self.transcriptPath = transcriptPath
        self.termProgram = termProgram
        self.tmuxPane = tmuxPane
        self.tmuxSocket = tmuxSocket
    }

    /// Last path component of the working directory — the human label.
    public var folderName: String {
        let name = (cwd as NSString).lastPathComponent
        return name.isEmpty ? cwd : name
    }

    public var needsAttention: Bool { phase == .waitingPermission || phase == .waitingQuestion }
    public var isActive: Bool { phase == .running || needsAttention }
}
