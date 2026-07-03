import Foundation

// 歌词(2026-07-03 用户:把媒体接真的)。同步歌词优先走 lrclib.net(免费无 key,
// 按 歌名+歌手+时长 命中 LRC);解析与选行是纯函数可测。拿不到就诚实显示无歌词,
// 不再放 demo 假词。

public struct LyricLine: Sendable, Equatable {
    public let time: Double  // 秒
    public let text: String

    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

public enum Lyrics: Sendable, Equatable {
    case none
    case plain([String])
    case synced([LyricLine])
}

/// 解析 LRC:支持一行多时间标签 `[01:23.45][01:40.1] 词`;非法行忽略。
public func parseLRC(_ raw: String) -> [LyricLine] {
    var out: [LyricLine] = []
    let tag = /\[(\d{1,2}):(\d{1,2})(?:[.:](\d{1,3}))?\]/
    for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
        let s = String(line)
        let matches = s.matches(of: tag)
        guard !matches.isEmpty else { continue }
        let text = s[matches.last!.range.upperBound...].trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { continue }
        for m in matches {
            let minutes = Double(m.1) ?? 0
            let seconds = Double(m.2) ?? 0
            let fracRaw = m.3.map(String.init) ?? "0"
            let frac = (Double(fracRaw) ?? 0) / pow(10, Double(fracRaw.count))
            out.append(LyricLine(time: minutes * 60 + seconds + frac, text: text))
        }
    }
    return out.sorted { $0.time < $1.time }
}

/// 当前行 = 最后一条 time <= position 的行;还没开唱返回 -1。
public func currentLyricIndex(_ lines: [LyricLine], position: Double) -> Int {
    var idx = -1
    for (i, l) in lines.enumerated() {
        if l.time <= position { idx = i } else { break }
    }
    return idx
}

/// lrclib.net 取词(注入 transport 可测)。404/断网 → .none,绝不抛。
public struct LyricsFetcher: Sendable {
    public typealias Transport = @Sendable (URL) async throws -> Data

    private let transport: Transport

    public init(transport: Transport? = nil) {
        self.transport = transport ?? { url in
            var req = URLRequest(url: url)
            req.timeoutInterval = 8
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.fileDoesNotExist)
            }
            return data
        }
    }

    public func fetch(title: String, artist: String, duration: Double?) async -> Lyrics {
        var comps = URLComponents(string: "https://lrclib.net/api/get")!
        var items = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist),
        ]
        if let d = duration, d > 0 {
            items.append(URLQueryItem(name: "duration", value: String(Int(d.rounded()))))
        }
        comps.queryItems = items
        guard let url = comps.url, let data = try? await transport(url),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return .none }
        if let lrc = obj["syncedLyrics"] as? String, !lrc.isEmpty {
            let lines = parseLRC(lrc)
            if !lines.isEmpty { return .synced(lines) }
        }
        if let plain = obj["plainLyrics"] as? String, !plain.isEmpty {
            let lines = plain.split(separator: "\n").map(String.init)
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !lines.isEmpty { return .plain(lines) }
        }
        return .none
    }
}
