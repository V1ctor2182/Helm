import AppKit
import HelmNotchCore

/// 轻量剪贴板监听:2s 轮询 NSPasteboard.changeCount,变了就把字符串内容
/// 记进 model.clipboardHistory(NOMI 暂存页剪贴板段的真实数据源——
/// 旧 seed 假数据随稿退役)。只留最近 5 条、连续重复不重记(model 侧兜底)。
@MainActor
final class ClipboardWatcher {
    private let model: NotchModel
    private var timer: Timer?
    private var lastChangeCount: Int

    init(model: NotchModel) {
        self.model = model
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        t.tolerance = 1
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        // 只收纯文本;长内容截断进历史(展示一行,存速记用全文前 2000)。
        guard let s = pb.string(forType: .string) else { return }
        model.recordClipboard(String(s.prefix(2000)))
    }
}
