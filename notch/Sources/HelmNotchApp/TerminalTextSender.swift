import AppKit
import Foundation
import HelmNotchCore

/// Injects a freeform reply into the terminal pane running an idle Claude Code
/// session (turn done, CLI waiting for the next prompt). Two routes, same as
/// open-vibe-island: tmux `send-keys` (precise, no focus needed) and Ghostty
/// AppleScript. Other terminals: no reply field (no reliable pane targeting).
enum TerminalTextSender {
    /// Can this session take a notch-side reply right now?
    static func canReply(to s: LocalSession) -> Bool {
        guard s.phase == .idle else { return false }
        if s.tmuxPane != nil { return true }
        return s.termProgram?.lowercased().contains("ghostty") == true
    }

    /// Send text + Enter to the session's pane. Returns an error message, nil on success.
    static func send(_ text: String, to s: LocalSession) -> String? {
        let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }
        if let pane = s.tmuxPane {
            return sendViaTmux(line, pane: pane, socket: s.tmuxSocket)
        }
        if s.termProgram?.lowercased().contains("ghostty") == true {
            return sendViaGhostty(line, cwd: s.cwd)
        }
        return "该终端不支持注入回复"
    }

    private static func sendViaTmux(_ text: String, pane: String, socket: String?) -> String? {
        // 文本与回车分两次发,-l 保证字面量(不解析按键名)。
        var base = ["tmux"]
        if let socket, !socket.isEmpty { base += ["-S", socket] }
        for args in [base + ["send-keys", "-t", pane, "-l", text],
                     base + ["send-keys", "-t", pane, "Enter"]] {
            if let err = runCommand(args) { return err }
        }
        return nil
    }

    private static func runCommand(_ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = args
        let errPipe = Pipe()
        p.standardError = errPipe
        do { try p.run() } catch { return "无法启动 \(args.first ?? "?")" }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            return msg?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? msg!.trimmingCharacters(in: .whitespacesAndNewlines) : "tmux 发送失败"
        }
        return nil
    }

    /// Ghostty: AppleScript `input text` into the terminal matching the session's
    /// cwd (fallback: frontmost). Needs the Automation permission on first use.
    private static func sendViaGhostty(_ text: String, cwd: String) -> String? {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedCwd = (cwd as NSString).lastPathComponent
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Ghostty"
            set target to missing value
            repeat with w in windows
                repeat with t in terminals of w
                    try
                        if (working directory of t) ends with "\(escapedCwd)" then
                            set target to t
                            exit repeat
                        end if
                    end try
                end repeat
                if target is not missing value then exit repeat
            end repeat
            if target is missing value then
                try
                    set target to current terminal of front window
                end try
            end if
            if target is missing value then error "找不到 Ghostty 终端"
            input text "\(escaped)" to target
            send key "enter" to target
        end tell
        """
        var errorDict: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
        if let errorDict, let msg = errorDict[NSAppleScript.errorMessage] as? String {
            return "Ghostty 注入失败:\(msg)"
        }
        return nil
    }
}
