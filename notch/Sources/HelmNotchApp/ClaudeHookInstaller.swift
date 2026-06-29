import Foundation

/// Installs / removes Helm Notch's hooks in `~/.claude/settings.json` so Claude
/// Code notifies the app of session lifecycle + permission requests. Our hook
/// command carries a marker so uninstall can find and strip exactly our entries.
enum ClaudeHookInstaller {
    /// Events we register. PermissionRequest gets a long timeout (it blocks for
    /// the user's verdict); the rest are fire-and-forget activity signals.
    private static let blockingEvents = ["PermissionRequest"]
    private static let activityEvents = [
        "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        "Notification", "Stop", "SubagentStop", "SessionEnd",
    ]

    /// Marker embedded in our hook command so we can recognize our own entries.
    private static let marker = "--hook helm-notch"

    static var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json")
    }

    /// The command Claude Code runs for each event (current app binary).
    private static func command() -> String {
        let bin = Bundle.main.executablePath ?? CommandLine.arguments[0]
        return "'\(bin)' \(marker)"
    }

    static func isInstalled() -> Bool {
        guard let dict = readSettings(), let hooks = dict["hooks"] as? [String: Any] else { return false }
        return hooks.values.contains { groups in
            (groups as? [[String: Any]])?.contains(where: groupIsOurs) ?? false
        }
    }

    @discardableResult
    static func install() throws -> URL? {
        var settings = readSettings() ?? [:]
        let backup = try backupIfPresent()
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]

        let cmd = command()
        for event in activityEvents + blockingEvents {
            var groups = stripOurs((hooks[event] as? [[String: Any]]) ?? [])
            var group: [String: Any] = ["hooks": [["type": "command", "command": cmd]]]
            if event == "PreToolUse" || event == "PostToolUse" || event == "Notification" {
                group["matcher"] = "*"
            }
            if blockingEvents.contains(event) {
                group["matcher"] = "*"
                group["timeout"] = 86_400
            }
            groups.append(group)
            hooks[event] = groups
        }
        settings["hooks"] = hooks
        try writeSettings(settings)
        return backup
    }

    static func uninstall() throws {
        guard var settings = readSettings(), var hooks = settings["hooks"] as? [String: Any] else { return }
        for (event, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let kept = stripOurs(groups)
            if kept.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = kept }
        }
        if hooks.isEmpty { settings.removeValue(forKey: "hooks") } else { settings["hooks"] = hooks }
        try writeSettings(settings)
    }

    // MARK: helpers

    private static func groupIsOurs(_ group: [String: Any]) -> Bool {
        guard let hooks = group["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { ($0["command"] as? String)?.contains(marker) ?? false }
    }

    private static func stripOurs(_ groups: [[String: Any]]) -> [[String: Any]] {
        groups.filter { !groupIsOurs($0) }
    }

    private static func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    private static func writeSettings(_ dict: [String: Any]) throws {
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(
            withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsURL, options: .atomic)
    }

    /// Timestamped backup of the existing settings before our first edit.
    private static func backupIfPresent() throws -> URL? {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return nil }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.helmbak.\(stamp)")
        try? FileManager.default.copyItem(at: settingsURL, to: backup)
        return backup
    }
}
