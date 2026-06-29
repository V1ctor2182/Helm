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
        let isPermission = (event == "PermissionRequest")

        let msg = HookMessage(event: event, session: session, cwd: cwd,
                              tool: tool, detail: detail, reply: isPermission)

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
            if let cmd = dict["command"] as? String { return "\(tool): \(cmd)" }
            if let path = dict["file_path"] as? String { return "\(tool): \(path)" }
        }
        return tool
    }

    /// Print the verdict in Claude Code's expected stdout schema for the event.
    private static func emitDecision(event: String, decision: Decision) {
        let allow = decision.behavior == "allow"
        let out: [String: Any]
        if event == "PermissionRequest" {
            var inner: [String: Any] = ["behavior": decision.behavior]
            if allow {
                inner["updatedInput"] = NSNull()
                inner["updatedPermissions"] = []
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
