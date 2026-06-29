import Darwin
import Foundation
import HelmNotchCore

/// Listens on the Unix-domain socket for Claude Code hook events (newline JSON),
/// folds them into the model, and — for PermissionRequest — parks the hook's
/// connection until the user taps 允许/拒绝, then writes the verdict back so the
/// blocked hook can print Claude Code's decision to stdout.
@MainActor
final class BridgeServer {
    private let model: NotchModel
    private let path: String
    private var listenFD: Int32 = -1
    /// session_id → the hook connection fd blocked awaiting a verdict.
    private var pending: [String: Int32] = [:]

    init(model: NotchModel, path: String = BridgeSocket.path()) {
        self.model = model
        self.path = path
    }

    func start() {
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        _ = withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cs in
                strncpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cs, 104)
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, len) }
        }
        guard bound == 0, listen(fd, 16) == 0 else { close(fd); return }
        listenFD = fd

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop(fd)
        }
    }

    func stop() {
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
        unlink(path)
    }

    // MARK: Accept / read (background)

    private nonisolated func acceptLoop(_ fd: Int32) {
        while true {
            let conn = accept(fd, nil, nil)
            if conn < 0 { break }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                self?.readConnection(conn)
            }
        }
    }

    private nonisolated func readConnection(_ fd: Int32) {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fd, &chunk, chunk.count)
            if n <= 0 { break }
            buffer.append(contentsOf: chunk[0..<n])
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<nl)
                buffer.removeSubrange(buffer.startIndex...nl)
                if let msg = try? JSONDecoder().decode(HookMessage.self, from: line) {
                    Task { @MainActor [weak self] in self?.handle(msg, fd: fd) }
                }
            }
        }
        Task { @MainActor [weak self] in self?.connectionClosed(fd) }
        close(fd)
    }

    // MARK: Main-actor state

    private func handle(_ msg: HookMessage, fd: Int32) {
        model.applyHook(msg)
        if msg.reply { pending[msg.session] = fd }
    }

    private func connectionClosed(_ fd: Int32) {
        pending = pending.filter { $0.value != fd }
    }

    /// Write the verdict to the parked hook connection (called from the model).
    func resolve(_ session: String, allow: Bool) {
        guard let fd = pending.removeValue(forKey: session) else { return }
        let decision = Decision(behavior: allow ? "allow" : "deny",
                                message: allow ? nil : "用户在 Helm Notch 拒绝")
        guard var data = try? JSONEncoder().encode(decision) else { return }
        data.append(0x0A)
        data.withUnsafeBytes { raw in
            _ = write(fd, raw.baseAddress, raw.count)
        }
    }
}
