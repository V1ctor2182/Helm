import Foundation

/// IPC between the Claude Code hook (`HelmNotch --hook`) and the running app's
/// `BridgeServer`, over a Unix-domain socket carrying newline-delimited JSON.
/// Both ends are ours, so the schema is deliberately small.
public enum BridgeSocket {
    /// Socket path: `HELM_NOTCH_SOCKET` override, else
    /// `~/Library/Application Support/HelmNotch/bridge.sock`.
    public static func path() -> String {
        let env = ProcessInfo.processInfo.environment
        if let p = env["HELM_NOTCH_SOCKET"], !p.isEmpty { return p }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let dir = base?.appendingPathComponent("HelmNotch", isDirectory: true) {
            return dir.appendingPathComponent("bridge.sock").path
        }
        return "/tmp/helm-notch.sock"
    }
}

/// One hook event, hook → server. `reply == true` (PermissionRequest) means the
/// hook is blocked waiting for a `Decision` back; everything else is fire-and-forget.
public struct HookMessage: Codable, Sendable, Equatable {
    public var event: String       // SessionStart / PreToolUse / PermissionRequest / Stop / SessionEnd / Notification / UserPromptSubmit …
    public var session: String     // Claude session_id
    public var cwd: String?
    public var tool: String?       // tool_name (PreToolUse / PermissionRequest)
    public var detail: String?     // short human summary (e.g. the bash command)
    public var reply: Bool         // expects a Decision back
    // Session-detail payload (all optional so老 hook 二进制的消息照常解码):
    public var toolInput: String?  // raw tool_input JSON (PermissionRequest — 选择题解析用)
    public var prompt: String?     // the user's prompt text (UserPromptSubmit)
    public var assistant: String?  // last assistant message (Stop — read from transcript tail)
    public var transcriptPath: String?
    // Terminal identity for idle-reply injection (from the hook's inherited env):
    public var term: String?       // TERM_PROGRAM (ghostty / iTerm.app / …)
    public var tmuxPane: String?   // $TMUX_PANE (e.g. "%5") — present inside tmux
    public var tmuxSocket: String? // socket path, first field of $TMUX

    public init(event: String, session: String, cwd: String? = nil,
                tool: String? = nil, detail: String? = nil, reply: Bool = false,
                toolInput: String? = nil, prompt: String? = nil, assistant: String? = nil,
                transcriptPath: String? = nil, term: String? = nil,
                tmuxPane: String? = nil, tmuxSocket: String? = nil) {
        self.event = event
        self.session = session
        self.cwd = cwd
        self.tool = tool
        self.detail = detail
        self.reply = reply
        self.toolInput = toolInput
        self.prompt = prompt
        self.assistant = assistant
        self.transcriptPath = transcriptPath
        self.term = term
        self.tmuxPane = tmuxPane
        self.tmuxSocket = tmuxSocket
    }
}

/// Permission verdict, server → hook. The hook translates it into Claude Code's
/// expected stdout JSON.
public struct Decision: Codable, Sendable, Equatable {
    public var behavior: String    // "allow" | "deny"
    public var message: String?
    /// Replacement tool_input JSON — allow-with-answers for AskUserQuestion.
    public var updatedInput: String?

    public init(behavior: String, message: String? = nil, updatedInput: String? = nil) {
        self.behavior = behavior
        self.message = message
        self.updatedInput = updatedInput
    }
}
