import HelmNotchCore
import SwiftUI

/// 选择题横幅 — Claude 的 AskUserQuestion 直接在 notch 里作答(点选/多选/
/// 其他自由填),提交后答案经阻塞 hook 的 updatedInput 注回 CLI。
/// 设计语言同 permissionBanner:黑底横幅、620 宽、单色字形,主色用每日 accent。
struct QuestionBannerView: View {
    let session: LocalSession
    let accent: Color
    @Bindable var model: NotchModel

    /// item index → selected option indices / freeform text.
    @State private var picks: [Int: Set<Int>] = [:]
    @State private var freeform: [Int: String] = [:]
    @FocusState private var freeformFocused: Bool

    private var items: [QuestionPrompt.Item] { session.question?.items ?? [] }
    private let numerals = ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(accent).frame(width: 7, height: 7)
                    Text("Claude 提问 · \(session.folderName)")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(accent)
                }
                Spacer()
                Text("选择后提交 — 无需回终端").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.indices, id: \.self) { qi in questionBlock(qi) }
                }
                .padding(.top, 10)
            }
            HStack(spacing: 10) {
                Button {
                    // 不作答放行:CLI 会在终端弹自己的选择器。
                    model.resolveLocalPermission(session.id, allow: true)
                } label: {
                    Text("终端作答").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 108).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1)))
                }.buttonStyle(.plain)
                Button(action: submit) {
                    Text("提交答案").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canSubmit ? Color(red: 0.1, green: 0.07, blue: 0.03) : .white.opacity(0.4))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(canSubmit ? AnyShapeStyle(accent) : AnyShapeStyle(.white.opacity(0.08))))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
    }

    @ViewBuilder private func questionBlock(_ qi: Int) -> some View {
        let item = items[qi]
        VStack(alignment: .leading, spacing: 6) {
            if !item.header.isEmpty {
                Text(item.header.uppercased())
                    .font(.system(size: 9, weight: .bold)).tracking(0.6)
                    .foregroundStyle(.white.opacity(0.35))
            }
            Text(item.question)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(item.options.indices, id: \.self) { oi in optionRow(qi, oi) }
            if pickedFreeform(qi) {
                TextField("输入你的回答…", text: bindingFreeform(qi))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(.white)
                    .focused($freeformFocused)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(.black.opacity(0.4)))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(accent.opacity(0.5), lineWidth: 1))
                    .onSubmit { if canSubmit { submit() } }
            }
        }
    }

    private func optionRow(_ qi: Int, _ oi: Int) -> some View {
        let item = items[qi]
        let opt = item.options[oi]
        let on = picks[qi]?.contains(oi) ?? false
        let glyph = item.multiSelect ? (on ? "◼" : "◻") : (on ? "●" : numerals[min(oi, numerals.count - 1)])
        return Button {
            var set = picks[qi] ?? []
            if item.multiSelect {
                if on { set.remove(oi) } else { set.insert(oi) }
            } else {
                set = on ? [] : [oi]
            }
            picks[qi] = set
            if opt.allowsFreeform && !on { freeformFocused = true }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(glyph).font(.system(size: 11)).foregroundStyle(on ? accent : .white.opacity(0.45))
                    .frame(width: 14, alignment: .center)
                Text(opt.label)
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? .white : .white.opacity(0.75))
                    .lineLimit(2)
                if !opt.detail.isEmpty {
                    Text(opt.detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(on ? accent.opacity(0.14) : .white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(on ? accent.opacity(0.55) : .white.opacity(0.08), lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pickedFreeform(_ qi: Int) -> Bool {
        guard let set = picks[qi] else { return false }
        return set.contains { items[qi].options[$0].allowsFreeform }
    }

    private func bindingFreeform(_ qi: Int) -> Binding<String> {
        Binding(get: { freeform[qi] ?? "" }, set: { freeform[qi] = $0 })
    }

    /// Every question answered; a picked "其他" needs non-empty text.
    private var canSubmit: Bool {
        for qi in items.indices {
            guard let set = picks[qi], !set.isEmpty else { return false }
            if pickedFreeform(qi),
               (freeform[qi] ?? "").trimmingCharacters(in: .whitespaces).isEmpty { return false }
        }
        return !items.isEmpty
    }

    private func submit() {
        var answers: [String: String] = [:]
        for (qi, item) in items.enumerated() {
            var parts: [String] = []
            for oi in (picks[qi] ?? []).sorted() {
                let opt = item.options[oi]
                parts.append(opt.allowsFreeform
                    ? freeform[qi, default: ""].trimmingCharacters(in: .whitespaces)
                    : opt.label)
            }
            answers[item.question] = parts.joined(separator: ", ")
        }
        model.resolveLocalQuestion(session.id, answers: answers)
    }
}

/// 会话详情页 — Dev/Agents 列表点行进入:最近 prompt、当前动作、Claude 的
/// 最后回复,以及 idle 时的自由回复框(tmux/Ghostty 注入回终端)。
struct SessionDetailView: View {
    let session: LocalSession
    let accent: Color
    @Bindable var model: NotchModel

    @State private var reply = ""
    @State private var sendState: String?
    @FocusState private var replyFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { model.selectedLocalSessionID = nil } label: {
                    Text("‹ 返回").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.56))
                }.buttonStyle(.plain)
                Text(session.folderName).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Circle().fill(phaseColor).frame(width: 6, height: 6)
                Text(phaseLabel).font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
            }
            Text(session.cwd)
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                .lineLimit(1).truncationMode(.head)
                .padding(.top, 2)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    if let prompt = session.lastPrompt {
                        block(label: "你 ›", text: prompt, textColor: .white.opacity(0.7))
                    }
                    if session.phase == .running {
                        HStack(spacing: 6) {
                            SpinningStar(color: accent).scaleEffect(0.78)
                            if let act = session.activity, act != "正在思考…" {
                                Text(act).font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.6)).lineLimit(2)
                            } else {
                                ShineText("正在思考…", accent: accent, size: 10)
                            }
                        }
                    }
                    if let assistant = session.lastAssistant {
                        block(label: "✻ CLAUDE", text: assistant, textColor: .white.opacity(0.88))
                    } else if session.phase != .running && session.lastPrompt == nil {
                        Text("等待 hook 事件带回内容…")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.3))
                    }
                }
                .padding(.top, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if session.phase == .idle {
                replyBar.padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var replyBar: some View {
        if TerminalTextSender.canReply(to: session) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    TextField("回复这个会话…", text: $reply)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11)).foregroundStyle(.white)
                        .focused($replyFocused)
                        .onSubmit(sendReply)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .stroke(replyFocused ? accent.opacity(0.6) : .white.opacity(0.1), lineWidth: 1))
                    Button(action: sendReply) {
                        Text("发送").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(reply.isEmpty ? .white.opacity(0.35) : Color(red: 0.1, green: 0.07, blue: 0.03))
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(Capsule().fill(reply.isEmpty ? AnyShapeStyle(.white.opacity(0.08)) : AnyShapeStyle(accent)))
                    }
                    .buttonStyle(.plain)
                    .disabled(reply.isEmpty)
                }
                if let sendState {
                    Text(sendState).font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
                }
            }
            // 输入时锁住面板,别让 hover 离开把它折叠掉。
            .onChange(of: replyFocused) { _, focused in
                if focused { model.beginCapture() } else { model.endInteraction() }
            }
        } else {
            Text("在 tmux 或 Ghostty 里跑的会话可直接从这里回复")
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
        }
    }

    private func sendReply() {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // 同步发:tmux 毫秒级,NSAppleScript 本就要主线程。
        if let err = TerminalTextSender.send(text, to: session) {
            sendState = err
        } else {
            sendState = "已发送 → 终端"
            reply = ""
        }
    }

    private func block(label: String, text: String, textColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold)).tracking(0.6)
                .foregroundStyle(.white.opacity(0.35))
            Text(text)
                .font(.system(size: 11)).foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    private var phaseColor: Color {
        switch session.phase {
        case .running: .green
        case .waitingPermission, .waitingQuestion: .orange
        case .idle: .white.opacity(0.55)
        case .ended: .white.opacity(0.35)
        }
    }

    private var phaseLabel: String {
        switch session.phase {
        case .running: "运行中"
        case .waitingPermission: "待批准"
        case .waitingQuestion: "待作答"
        case .idle: "空闲 — 可回复"
        case .ended: "已结束"
        }
    }
}
