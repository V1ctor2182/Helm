import Foundation
import HelmNotchCore

/// Now-playing via boring.notch's `mediaremote-adapter` (BSD-3, vendored under
/// Resources/). macOS 15.4+ blocks MediaRemote for non-platform binaries, so we
/// run the query through `/usr/bin/perl` (an Apple platform binary) loading the
/// signed `MediaRemoteAdapter.framework` — the daemon allows the platform-binary
/// caller. This is what actually returns track/artist/artwork on current macOS.
final class AdapterMediaController: MediaController, @unchecked Sendable {
    private let scriptPath: String?
    private let frameworkPath: String?

    init() {
        let dir = Self.resourceDir()
        let script = dir?.appendingPathComponent("mediaremote-adapter.pl").path
        let framework = dir?.appendingPathComponent("MediaRemoteAdapter.framework").path
        scriptPath = script.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
        frameworkPath = framework.flatMap { FileManager.default.fileExists(atPath: $0) ? $0 : nil }
    }

    /// Locate the vendored adapter: app bundle Resources, an explicit override,
    /// or the SwiftPM build's bundled resources (dev `swift run`).
    private static func resourceDir() -> URL? {
        // 开发直跑(.build/debug/HelmNotchApp):可执行文件 ../../Resources 就是仓内
        // vendored 目录——没有这个回退,裸 nohup 重启会把媒体探测悄悄弄哑
        // (2026-07-03 真机踩坑:Apple Music 在放却检测不到)。
        let exeDir = Bundle.main.executableURL?.deletingLastPathComponent()
        let candidates: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent("mediaremote-adapter"),
            ProcessInfo.processInfo.environment["HELM_NOTCH_ADAPTER"].map { URL(fileURLWithPath: $0) },
            exeDir?.appendingPathComponent("../../Resources/mediaremote-adapter").standardizedFileURL,
        ]
        for case let url? in candidates where FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    var isAvailable: Bool { scriptPath != nil && frameworkPath != nil }

    func nowPlaying() async -> NowPlaying? {
        guard let scriptPath, let frameworkPath else { return nil }
        guard let data = await run([scriptPath, frameworkPath, "get"]),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let title = dict["title"] as? String, !title.isEmpty
        else { return nil }

        let artist = (dict["artist"] as? String)
            ?? (dict["composer"] as? String)
            ?? (dict["album"] as? String) ?? ""
        let playing: Bool
        if let flag = dict["playing"] as? Bool {
            playing = flag
        } else if let rate = dict["playbackRate"] as? Double {
            playing = rate > 0
        } else {
            playing = true
        }
        // MediaRemote 的 elapsedTime 是「上次状态变化时的快照」,不随播放递增——
        // 必须用同 payload 的 timestamp 折算到当下,否则每次轮询都把位置拉回
        // 快照值(实测 6s 只走 1s),livePosition 冻结、歌词不滚(2026-07-04)。
        var elapsed = number(dict, "elapsedTime", "elapsed", "position")
        if playing, let snap = elapsed, let ts = dict["timestamp"] as? String,
           let snapAt = ISO8601DateFormatter().date(from: ts) {
            elapsed = snap + max(0, Date().timeIntervalSince(snapAt))
        }
        return NowPlaying(
            title: title,
            artist: artist,
            isPlaying: playing,
            artworkBase64: dict["artworkData"] as? String,
            elapsed: elapsed,
            duration: number(dict, "duration", "totalTime", "length"))
    }

    /// First numeric value among the given keys (adapter spells these a few ways).
    private func number(_ dict: [String: Any], _ keys: String...) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double { return value }
            if let value = dict[key] as? Int { return Double(value) }
            if let str = dict[key] as? String, let value = Double(str) { return value }
        }
        return nil
    }

    // MRCommand IDs: 0 play, 1 pause, 2 togglePlayPause, 4 next, 5 previous.
    func playPause() { fire(["send", "2"]) }
    func nextTrack() { fire(["send", "4"]) }
    func previousTrack() { fire(["send", "5"]) }

    private func fire(_ command: [String]) {
        guard let scriptPath, let frameworkPath else { return }
        let args = [scriptPath, frameworkPath] + command
        Task.detached { _ = await self.run(args) }
    }

    /// Spawn `/usr/bin/perl <args>` and return stdout. Reads the pipe to EOF on a
    /// background thread so large artwork output can't deadlock the pipe buffer.
    private func run(_ args: [String]) async -> Data? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
                process.arguments = args
                let out = Pipe()
                process.standardOutput = out
                process.standardError = Pipe()
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = out.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: data.isEmpty ? nil : data)
            }
        }
    }
}
