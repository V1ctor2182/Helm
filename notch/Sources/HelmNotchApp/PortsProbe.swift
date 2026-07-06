import Foundation
import HelmNotchCore

/// 真端口探测:`lsof -nP -iTCP -sTCP:LISTEN` 解析出 (端口, 进程名)。
/// NOMI 智能体·端口子页的数据源——旧 portSeed 假数据随稿退役。
enum PortsProbe {
    static func listListeningPorts() -> [PortInfo] {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        p.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "cn"]  // -F cn: per-process c<cmd>, per-fd n<addr>
        let out = Pipe()
        p.standardOutput = out
        p.standardError = Pipe()
        do { try p.run() } catch { return [] }
        // lsof 输出有限;先读完再 wait,避免管道写满互等
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var current = ""
        var seen: [Int: String] = [:]
        for line in text.split(separator: "\n") {
            guard let tag = line.first else { continue }
            let rest = String(line.dropFirst())
            switch tag {
            case "c":
                current = rest
            case "n":
                // n*:5174 / n127.0.0.1:8769 / n[::1]:8021 → 取最后一个冒号后的端口
                if let colon = rest.lastIndex(of: ":"), let port = Int(rest[rest.index(after: colon)...]),
                   seen[port] == nil {
                    seen[port] = current
                }
            default:
                break
            }
        }
        return seen.map { PortInfo(port: $0.key, name: $0.value) }
    }
}
