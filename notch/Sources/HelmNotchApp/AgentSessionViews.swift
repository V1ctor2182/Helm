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
                    SparkDot()
                    Text("claude · \(session.folderName)").font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(Color(model.nomi.ink))
                    Text("提问").font(.system(size: 11.5)).foregroundStyle(Color(model.nomi.ink2))
                }
                Spacer()
                Text("选择后提交 — 无需回终端").font(.system(size: 10)).foregroundStyle(Color(model.nomi.ink3))
            }
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(items.indices, id: \.self) { qi in questionBlock(qi) }
                }
                .padding(.top, 10)
            }
            HStack(spacing: 10) {
                Button("终端作答") { model.resolveLocalPermission(session.id, allow: true) }
                    .buttonStyle(PillButtonStyle(palette: model.nomi, fontSize: 12))
                Button("打开会话") { model.openPendingSession() }
                    .buttonStyle(PillButtonStyle(palette: model.nomi, fontSize: 12))
                Button(action: submit) {
                    Text("提交答案").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(canSubmit ? .white : Color(model.nomi.ink3))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(Capsule()
                            .fill(canSubmit ? AnyShapeStyle(Nomi.gradientH) : AnyShapeStyle(Color(model.nomi.pill))))
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
                    .foregroundStyle(Color(model.nomi.ink3))
            }
            Text(item.question)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(model.nomi.ink))
                .fixedSize(horizontal: false, vertical: true)
            ForEach(item.options.indices, id: \.self) { oi in optionRow(qi, oi) }
            if pickedFreeform(qi) {
                TextField("", text: bindingFreeform(qi), prompt: Text("输入你的回答…").foregroundStyle(Color(model.nomi.ink3)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 11)).foregroundStyle(Color(model.nomi.ink))
                    .focused($freeformFocused)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(model.nomi.pill)))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(NomiTheme.g1).opacity(0.5), lineWidth: 1))
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
                Text(glyph).font(.system(size: 11)).foregroundStyle(on ? Color(NomiTheme.g1) : Color(model.nomi.ink3))
                    .frame(width: 14, alignment: .center)
                Text(opt.label)
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(Color(model.nomi.ink).opacity(on ? 1 : 0.8))
                    .lineLimit(2)
                if !opt.detail.isEmpty {
                    Text(opt.detail).font(.system(size: 10)).foregroundStyle(Color(model.nomi.ink3))
                        .lineLimit(1).truncationMode(.tail)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color(model.nomi.pill).opacity(on ? 1 : 0.55)))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(on ? AnyShapeStyle(Nomi.gradient) : AnyShapeStyle(Color(model.nomi.hair)), lineWidth: on ? 1.5 : 1))
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
                    Text("‹ 返回").font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(model.nomi.ink2))
                }.buttonStyle(.plain)
                Text(session.folderName).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(model.nomi.ink))
                    .lineLimit(1)
                Spacer()
                Circle().fill(phaseColor).frame(width: 6, height: 6)
                Text(phaseLabel).font(.system(size: 9)).foregroundStyle(Color(model.nomi.ink3))
            }
            Text(session.cwd)
                .font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(model.nomi.ink3))
                .lineLimit(1).truncationMode(.head)
                .padding(.top, 2)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 9) {
                    if let prompt = session.lastPrompt {
                        block(label: "你 ›", text: prompt, textColor: Color(model.nomi.ink2))
                    }
                    if session.phase == .running {
                        HStack(spacing: 6) {
                            SpinningStar(color: accent).scaleEffect(0.78)
                            if let act = session.activity, act != "正在思考…" {
                                Text(act).font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Color(model.nomi.ink2)).lineLimit(2)
                            } else {
                                ShineText("正在思考…", accent: accent, size: 10)
                            }
                        }
                    }
                    if let assistant = session.lastAssistant {
                        block(label: "✻ CLAUDE", text: assistant, textColor: Color(model.nomi.ink))
                    } else if session.phase != .running && session.lastPrompt == nil {
                        Text("等待 hook 事件带回内容…")
                            .font(.system(size: 10)).foregroundStyle(Color(model.nomi.ink3))
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
                    TextField("", text: $reply, prompt: Text("回复这个会话…").foregroundStyle(Color(model.nomi.ink3)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11)).foregroundStyle(Color(model.nomi.ink))
                        .focused($replyFocused)
                        .onSubmit(sendReply)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color(model.nomi.pill)))
                        .overlay(RoundedRectangle(cornerRadius: 9)
                            .stroke(replyFocused ? Color(NomiTheme.g1).opacity(0.6) : Color(model.nomi.hair), lineWidth: 1))
                    Button(action: sendReply) {
                        Text("发送").font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(reply.isEmpty ? Color(model.nomi.ink3) : .white)
                            .padding(.horizontal, 13).padding(.vertical, 7)
                            .background(Capsule().fill(reply.isEmpty ? AnyShapeStyle(Color(model.nomi.pill)) : AnyShapeStyle(Nomi.gradientH)))
                    }
                    .buttonStyle(.plain)
                    .disabled(reply.isEmpty)
                }
                if let sendState {
                    Text(sendState).font(.system(size: 9)).foregroundStyle(Color(model.nomi.ink3))
                }
            }
            // 输入时锁住面板,别让 hover 离开把它折叠掉。
            .onChange(of: replyFocused) { _, focused in
                if focused { model.beginCapture() } else { model.endInteraction() }
            }
        } else {
            Text("在 tmux 或 Ghostty 里跑的会话可直接从这里回复")
                .font(.system(size: 9)).foregroundStyle(Color(model.nomi.ink3))
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
                .foregroundStyle(Color(model.nomi.ink3))
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
        case .idle: Color(model.nomi.ink3)
        case .ended: Color(model.nomi.hair)
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
