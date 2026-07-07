import Darwin
import Foundation
import HelmNotchCore

/// `HelmNotch --hook` mode: invoked by Claude Code for each hook event. Reads the
/// event JSON on stdin, relays it to the running app over the bridge socket, and
/// — for PermissionRequest — blocks for the user's verdict then prints Claude
/// Code's decision JSON to stdout. If the app isn't running (no socket) or it
/// times out, it stays silent so Claude falls back to its normal prompt
/// (never blocks the CLI).
enum HookRunner {
    static func run() -> Never {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let payload = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]

        let event = payload["hook_event_name"] as? String ?? "Unknown"
        let session = payload["session_id"] as? String ?? "unknown"
        let cwd = payload["cwd"] as? String
        let tool = payload["tool_name"] as? String
        let detail = summarize(tool: tool, input: payload["tool_input"])
        let transcriptPath = payload["transcript_path"] as? String
        let isPermission = (event == "PermissionRequest")

        // 原始 tool_input 只在 PermissionRequest 带上(选择题解析/答案合并要用)。
        var toolInputJSON: String?
        if isPermission, let ti = payload["tool_input"],
           JSONSerialization.isValidJSONObject(ti),
           let data = try? JSONSerialization.data(withJSONObject: ti) {
            toolInputJSON = String(data: data, encoding: .utf8)
        }

        // UserPromptSubmit 的 prompt / Stop 时从 transcript 尾部捞最后一条回复,
        // 喂给 notch 的会话详情页。
        let prompt = (event == "UserPromptSubmit") ? clip(payload["prompt"] as? String, 400) : nil
        let assistant = (event == "Stop") ? clip(lastAssistantMessage(transcriptPath), 1600) : nil

        // 终端身份(hook 继承 CLI 的环境):idle 回复注入的路由信息。
        let env = ProcessInfo.processInfo.environment
        let tmuxSocket = env["TMUX"].flatMap { $0.split(separator: ",").first.map(String.init) }

        let msg = HookMessage(event: event, session: session, cwd: cwd,
                              tool: tool, detail: detail, reply: isPermission,
                              toolInput: toolInputJSON, prompt: prompt, assistant: assistant,
                              transcriptPath: transcriptPath, term: env["TERM_PROGRAM"],
                              tmuxPane: env["TMUX_PANE"], tmuxSocket: tmuxSocket)

        guard let client = HookClient(path: BridgeSocket.path()) else {
            exit(0)  // app not running → passthrough
        }
        client.send(msg)

        if isPermission, let decision = client.readDecision() {
            emitDecision(event: event, decision: decision)
        }
        exit(0)
    }

    /// A short human label for the tool call (the bash command, or the tool name).
    private static func summarize(tool: String?, input: Any?) -> String? {
        guard let tool else { return nil }
        if let dict = input as? [String: Any] {
            // 选择题:把题面+选项带给横幅,别只显示一个干巴巴的工具名
            if tool == "AskUserQuestion",
               let qs = dict["questions"] as? [[String: Any]], let q0 = qs.first {
                var lines: [String] = []
                if let q = q0["question"] as? String { lines.append(q) }
                let marks = ["①", "②", "③", "④"]
                for (i, o) in ((q0["options"] as? [[String: Any]]) ?? []).prefix(4).enumerated() {
                    if let label = o["label"] as? String { lines.append("\(marks[i]) \(label)") }
                }
                if !lines.isEmpty { return lines.joined(separator: "\n") }
            }
            if let cmd = dict["command"] as? String { return "\(tool): \(cmd)" }
            if let path = dict["file_path"] as? String { return "\(tool): \(path)" }
        }
        return tool
    }

    private static func clip(_ s: String?, _ max: Int) -> String? {
        guard let s, !s.isEmpty else { return nil }
        return s.count <= max ? s : String(s.prefix(max)) + "…"
    }

    /// Tail-read the transcript JSONL and return the last assistant text —
    /// what the Stop-time detail view shows as "Claude 的最后回复".
    private static func lastAssistantMessage(_ path: String?) -> String? {
        guard let path, let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        let window: UInt64 = 256 * 1024
        let start = size > window ? size - window : 0
        try? fh.seek(toOffset: start)
        guard let data = try? fh.readToEnd(),
              let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.split(separator: "\n").reversed() {
            guard let obj = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  obj["type"] as? String == "assistant",
                  let message = obj["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { continue }
            let texts = content.compactMap { block -> String? in
                block["type"] as? String == "text" ? (block["text"] as? String) : nil
            }
            let joined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { return joined }
        }
        return nil
    }

    /// Print the verdict in Claude Code's expected stdout schema for the event.
    private static func emitDecision(event: String, decision: Decision) {
        let allow = decision.behavior == "allow"
        let out: [String: Any]
        if event == "PermissionRequest" {
            var inner: [String: Any] = ["behavior": decision.behavior]
            if allow {
                // 选择题:答案已合并进 updatedInput,工具照常执行但带上用户的选择。
                // 没有 updatedInput 就整个省略——发 null/空数组会被 Claude Code
                // 判无效丢弃,Allow 形同虚设(2026-07-07 用户:Allow 没反应)。
                if let json = decision.updatedInput,
                   let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) {
                    inner["updatedInput"] = obj
                }
            } else {
                inner["message"] = decision.message ?? "Denied in Helm Notch."
                inner["interrupt"] = false
            }
            out = [
                "continue": true,
                "suppressOutput": true,
                "hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": inner],
            ]
        } else {
            out = [
                "hookSpecificOutput": [
                    "hookEventName": event,
                    "permissionDecision": allow ? "allow" : "deny",
                    "permissionDecisionReason": decision.message ?? "Helm Notch",
                ]
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: out) {
            FileHandle.standardOutput.write(data)
        }
    }
}

/// Minimal blocking Unix-socket client for the hook process.
private final class HookClient {
    private let fd: Int32

    init?(path: String) {
        fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cs in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cs, 104)
            }
        }
        // Don't let a wedged app hang Claude: 1h receive cap (verdict can be slow).
        var tv = timeval(tv_sec: 3600, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let ok = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
        }
        if ok != 0 { close(fd); return nil }
    }

    deinit { close(fd) }

    func send(_ msg: HookMessage) {
        guard var data = try? JSONEncoder().encode(msg) else { return }
        data.append(0x0A)
        data.withUnsafeBytes { _ = write(fd, $0.baseAddress, $0.count) }
    }

    func readDecision() -> Decision? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 1024)
        while true {
            let n = read(fd, &chunk, chunk.count)
            if n <= 0 { return nil }
            buffer.append(contentsOf: chunk[0..<n])
            if let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<nl)
                return try? JSONDecoder().decode(Decision.self, from: line)
            }
        }
    }
}
