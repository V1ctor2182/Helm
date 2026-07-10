import AppKit
import HelmNotchCore
import SwiftUI

/// 日记续写的富文本编辑器(面板内,2026-07-10 用户:今天卡续写按钮开弹层)。
/// NSTextView 撑起选区包裹——B/I/H 把选中文字裹上 md 兼容标记(**粗**/*斜*/
/// <mark>高亮</mark>),存储仍是纯文本 md,与主 app / notch journalToday / enrich 一致。
/// 抢方向盘编辑,不回主 app。

/// 选区格式化器:持有 NSTextView,把当前选区裹上 (前缀, 后缀)。
final class JournalFormatter {
    weak var textView: NSTextView?

    func wrap(_ prefix: String, _ suffix: String) {
        guard let tv = textView else { return }
        let sel = tv.selectedRange()
        let ns = tv.string as NSString
        let picked = ns.substring(with: sel)
        let replacement = prefix + picked + suffix
        guard tv.shouldChangeText(in: sel, replacementString: replacement) else { return }
        tv.textStorage?.replaceCharacters(in: sel, with: replacement)
        tv.didChangeText()
        // 选区保持在原文本上(标记外),没选中则光标落进标记中间。
        let caret = sel.location + (prefix as NSString).length
        tv.setSelectedRange(NSRange(location: caret, length: (picked as NSString).length))
        tv.window?.makeFirstResponder(tv)
    }
}

/// 面板内的 NOMI 风纯文本编辑器(透明底,主题墨色)。
struct JournalTextEditor: NSViewRepresentable {
    @Binding var text: String
    let formatter: JournalFormatter
    let pal: NomiPalette

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        guard let tv = scroll.documentView as? NSTextView else { return scroll }
        tv.delegate = context.coordinator
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .systemFont(ofSize: 13)
        tv.textColor = NSColor(pal.ink)
        tv.insertionPointColor = NSColor(NomiTheme.g1)
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 4, height: 6)
        tv.string = text
        formatter.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let tv = scroll.documentView as? NSTextView else { return }
        formatter.textView = tv
        tv.textColor = NSColor(pal.ink)
        if tv.string != text {
            let sel = tv.selectedRange()
            tv.string = text
            let loc = min(sel.location, (text as NSString).length)
            tv.setSelectedRange(NSRange(location: loc, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            text.wrappedValue = tv.string
        }
    }
}
