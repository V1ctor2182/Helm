import AppKit
import HelmNotchCore
import SwiftUI

/// The notch surface (A×D fusion). Collapsed: two slots hugging the physical
/// notch, camera gap left clear. Hover → expand into a fixed 2×2 panel
/// (媒体 ↖ · 日历 ↗ · 本机 agent ↙ · 速记 ↘). The grid never deforms; the active
/// cell "comes alive": 速记 locks the panel for keyboard input, an agent waiting
/// on permission lights its cell. Accent color rotates daily.
struct NotchView: View {
    @Bindable var model: NotchModel
    @FocusState private var captureFocused: Bool

    private var accent: Color { Color(model.accent) }

    private let collapsedBarHeight: CGFloat = 32
    private var collapsedWidth: CGFloat { CGFloat(model.notchWidth) + 150 }

    var body: some View {
        let shellW = model.expanded ? model.expandedWidth : collapsedWidth
        let shellH = model.expanded ? model.expandedHeight : collapsedBarHeight
        shell(width: shellW, height: shellH)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onExitCommand { captureFocused = false; model.locked ? model.endInteraction() : model.collapse() }
            // Focus drives the lock: clicking the field focuses it (panel becomes
            // key) → lock open; losing focus (Esc / click-away) → unlock.
            .onChange(of: captureFocused) { _, focused in
                if focused { model.beginCapture() } else { model.endInteraction() }
            }
            .onChange(of: model.locked) { _, locked in if !locked { captureFocused = false } }
    }

    /// One continuous black shell that grows width+height out of the notch with
    /// iOS easing. Folded content fades out fast; the 2×2 grid fades + slides in
    /// after a short delay — grow the shell first, then reveal (no mush).
    private func shell(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            collapsedBar
                .opacity(model.expanded ? 0 : 1)
                .animation(.easeOut(duration: model.expanded ? 0.12 : 0.22), value: model.expanded)

            grid
                .frame(width: model.expandedWidth, height: model.expandedHeight, alignment: .top)
                .opacity(model.expanded ? 1 : 0)
                .offset(y: model.expanded ? 0 : -10)
                .allowsHitTesting(model.expanded)
                .animation(.easeOut(duration: 0.3).delay(model.expanded ? 0.12 : 0), value: model.expanded)
        }
        .frame(width: width, height: height, alignment: .top)
        .background(Color.black)
        .clipShape(NotchShape(bottomRadius: model.expanded ? 24 : 16))
        .overlay(alignment: .topTrailing) { if model.expanded { topControls } }
        .overlay(alignment: .bottomTrailing) { if model.expanded { resizeHandle } }
        .contentShape(Rectangle())
        .onHover { model.hover($0) }
        // iOS-style shell grow (content has its own, delayed, animations above).
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.5), value: model.expanded)
        .frame(maxWidth: .infinity, alignment: .top)  // center the shell in the canvas
    }

    // MARK: Collapsed — one continuous bar (left content · camera gap · right glyph)

    private var collapsedBar: some View {
        HStack(spacing: 0) {
            collapsedLeft
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 11)
            Color.clear.frame(width: CGFloat(model.notchWidth))  // physical notch / camera
            collapsedRight
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 11)
        }
        .frame(width: collapsedWidth, height: collapsedBarHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    @ViewBuilder private var collapsedLeft: some View {
        if let np = model.nowPlaying {
            HStack(spacing: 6) {
                collapsedArt(np)
                if np.isPlaying {
                    EqualizerBars(color: accent)
                } else {
                    Image(systemName: "pause.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                }
            }
        } else {
            HStack(spacing: 6) {
                Circle().fill(dotColor).frame(width: 6, height: 6)
                Text("Helm").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func collapsedArt(_ np: NowPlaying) -> some View {
        Group {
            if let art = nsArtwork(np) {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.91, green: 0.63, blue: 0.48), Color(red: 0.42, green: 0.31, blue: 0.56)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(width: 17, height: 17)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    /// Right glyph — Open Island-style morphing status, color + motion over text.
    @ViewBuilder private var collapsedRight: some View {
        let waiting = model.localSessions.filter(\.needsAttention).count
        let running = model.localSessions.filter { $0.phase == .running }.count
        if waiting > 0 {
            StatusGlyph(state: .waiting, count: waiting).glowingPill()
        } else if running > 0 {
            StatusGlyph(state: .running, count: running)
        } else if !model.events.isEmpty {
            HStack(spacing: 5) {
                Image(systemName: "checklist").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                Text("\(model.events.count)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                Text("今日").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
            }
        } else {
            Circle().fill(.white.opacity(0.22)).frame(width: 8, height: 8)
        }
    }

    // MARK: Expanded — fixed 2×2

    /// The 2×2 grid, laid out at full size; revealed as the shell grows.
    private var grid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) { cell { mediaCell }; vline; cell { calendarCell } }
            hline
            HStack(spacing: 0) { cell { agentCell }; vline; cell { captureCell } }
        }
        // Inset the grid from the rounded edges so nothing hugs the border.
        .padding(EdgeInsets(top: 14, leading: 9, bottom: 10, trailing: 9))
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            if model.locked {
                Button { model.collapse() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.white.opacity(0.45))
            }
            Button { model.openSettings?() } label: {
                Image(systemName: "gearshape.fill").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.4))
        }
        .padding(.top, 11).padding(.trailing, 13)
    }

    private func cell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 12).padding(.vertical, 11)
    }

    private var vline: some View { Rectangle().fill(.white.opacity(0.08)).frame(width: 0.5) }
    private var hline: some View { Rectangle().fill(.white.opacity(0.08)).frame(height: 0.5) }

    private func cellHeader(_ title: String, accentTitle: Bool = false, trailing: String? = nil, trailingColor: Color = .white.opacity(0.35)) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold)).tracking(0.6)
                .foregroundStyle(accentTitle ? accent : .white.opacity(0.35))
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 9, weight: .semibold)).foregroundStyle(trailingColor) }
        }
    }

    // MARK: Media cell ↖

    @ViewBuilder private var mediaCell: some View {
        cellHeader("♪ 正在播放")
        if let np = model.nowPlaying {
            HStack(spacing: 10) {
                artwork(np)
                VStack(alignment: .leading, spacing: 1) {
                    Text(np.title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text(np.subtitle.isEmpty ? " " : np.subtitle)
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(accent).lineLimit(1)
                }
            }
            .padding(.top, 6)
            progressBar(np).padding(.top, 8)
            transport(np).padding(.top, 6)
        } else {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)).frame(width: 56, height: 56)
                    .overlay(Image(systemName: "music.note").font(.system(size: 18)).foregroundStyle(.white.opacity(0.3)))
                Text("未在播放").font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(.top, 8)
        }
        Spacer(minLength: 0)
    }

    private func artwork(_ np: NowPlaying) -> some View {
        ZStack {
            if let art = nsArtwork(np) {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56).blur(radius: 12).opacity(0.5).scaleEffect(1.15)
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.08)).frame(width: 56, height: 56)
                    .overlay(Image(systemName: "music.note").font(.system(size: 16)).foregroundStyle(.white.opacity(0.35)))
            }
        }
        .frame(width: 56, height: 56)
    }

    @ViewBuilder private func progressBar(_ np: NowPlaying) -> some View {
        if np.hasProgress {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let pos = model.livePosition(at: context.date)
                let total = np.duration ?? 0
                let frac = total > 0 ? min(1, pos / total) : 0
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.16))
                            Capsule().fill(accent).frame(width: max(2, geo.size.width * frac))
                        }
                    }
                    .frame(height: 4)
                    HStack {
                        Text(timeString(pos)); Spacer(); Text(timeString(total))
                    }
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func transport(_ np: NowPlaying) -> some View {
        HStack(spacing: 22) {
            Spacer(minLength: 0)
            Button { model.previousTrack() } label: { Image(systemName: "backward.fill").font(.system(size: 13)) }
            Button { model.playPause() } label: { Image(systemName: np.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 19)) }
            Button { model.nextTrack() } label: { Image(systemName: "forward.fill").font(.system(size: 13)) }
            Spacer(minLength: 0)
        }
        .buttonStyle(.plain).foregroundStyle(.white)
    }

    // MARK: Calendar cell ↗ (week strip works offline; events land in m2)

    @ViewBuilder private var calendarCell: some View {
        cellHeader("日历", trailing: monthLabel).padding(.trailing, 22)  // clear the gear
        HStack(spacing: 0) {
            ForEach(weekDays(), id: \.offset) { day in
                VStack(spacing: 2) {
                    Text(day.weekday).font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
                    Text("\(day.number)")
                        .font(.system(size: 12, weight: day.isToday ? .bold : .semibold))
                        .foregroundStyle(day.isToday ? .black : .white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background { if day.isToday { Circle().fill(accent) } }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        if model.events.isEmpty {
            Text("今天暂无事件").font(.system(size: 11)).foregroundStyle(.white.opacity(0.3)).padding(.top, 2)
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(model.events.prefix(3))) { ev in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 3)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ev.summary).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                            Text(ev.when).font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 2)
        }
        Spacer(minLength: 0)
    }

    // MARK: Agent cell ↙ (backend runs for now; local Claude Code lands in m3)

    @ViewBuilder private var agentCell: some View {
        let waiting = model.localSessions.filter(\.needsAttention)
        cellHeader(
            "◉ 本机 CLAUDE CODE",
            accentTitle: !waiting.isEmpty,
            trailing: waiting.isEmpty ? "\(model.localActiveCount) 活跃" : "\(waiting.count) 待批准",
            trailingColor: waiting.isEmpty ? .white.opacity(0.35) : .orange)
        if let perm = waiting.first {
            permissionCard(perm).padding(.top, 6)
        }
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(model.localSessions.filter { !$0.needsAttention }.prefix(waiting.isEmpty ? 3 : 0))) { session in
                HStack(spacing: 7) {
                    Circle().fill(phaseColor(session.phase)).frame(width: 6, height: 6)
                    Text(session.folderName).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                    if let act = session.activity, session.phase == .running {
                        Text(act).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4)).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(phaseShort(session.phase)).font(.system(size: 9)).foregroundStyle(.white.opacity(0.35))
                }
            }
            if model.localSessions.isEmpty {
                Text(ClaudeHookInstaller.isInstalled() ? "无本机 agent 在跑" : "未装监听 hook · 见设置 ⌘,")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.top, 6)
        Spacer(minLength: 0)
    }

    private func permissionCard(_ session: LocalSession) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("⚠︎ \(session.folderName) · 请求执行")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(red: 1, green: 0.85, blue: 0.64))
            Text(session.pendingDetail ?? session.pendingTool ?? "(请求权限)")
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.82))
                .lineLimit(1).padding(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.35)))
            HStack(spacing: 7) {
                Button("允许") { model.resolveLocalPermission(session.id, allow: true) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.black)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(accent))
                Button("拒绝") { model.resolveLocalPermission(session.id, allow: false) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }

    // MARK: Capture cell ↘

    @ViewBuilder private var captureCell: some View {
        cellHeader("✎ 速记", accentTitle: model.locked, trailing: model.locked ? "● 输入中" : nil, trailingColor: accent)
        HStack(spacing: 6) {
            ForEach(CaptureKind.allCases) { kind in
                let on = model.captureKind == kind
                Button(kind.label) { model.captureKind = kind }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? .black : .white.opacity(0.55))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(on ? accent : .white.opacity(0.08)))
            }
        }
        .padding(.top, 6)
        HStack(spacing: 8) {
            TextField(placeholder, text: $model.captureText, axis: .vertical)
                .textFieldStyle(.plain).font(.system(size: 12)).foregroundStyle(.white)
                .lineLimit(1...3).focused($captureFocused)
                .onSubmit { Task { await model.submit() } }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(model.locked ? 0.1 : 0.07)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(model.locked ? 0.5 : 0), lineWidth: 1))
            Button { Task { await model.submit() } } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 23))
                    .foregroundStyle(model.captureText.isEmpty ? .white.opacity(0.25) : accent)
            }
            .buttonStyle(.plain).disabled(model.captureText.isEmpty)
        }
        .padding(.top, 7)
        statusLabel.padding(.top, 2)
        Spacer(minLength: 0)
    }

    // MARK: Resize handle

    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.25))
            .padding(7)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        model.resize(
                            width: model.expandedWidth + value.translation.width * 2,
                            height: model.expandedHeight + value.translation.height)
                    }
            )
    }

    // MARK: Helpers

    private func nsArtwork(_ np: NowPlaying) -> NSImage? {
        guard let base64 = np.artworkBase64, let data = Data(base64Encoded: base64) else { return nil }
        return NSImage(data: data)
    }

    private func timeString(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let t = Int(seconds.rounded())
        return String(format: "%d:%02d", t / 60, t % 60)
    }

    private func phaseColor(_ phase: LocalSession.Phase) -> Color {
        switch phase {
        case .running: .green
        case .waitingPermission: .orange
        case .ended: .white.opacity(0.35)
        }
    }

    private func phaseShort(_ phase: LocalSession.Phase) -> String {
        switch phase {
        case .running: "运行中"
        case .waitingPermission: "待批准"
        case .ended: "完成"
        }
    }

    private var placeholder: String {
        switch model.captureKind {
        case .note: "随手记一笔…"
        case .journal: "今天发生了什么?"
        case .task: "到点让 agent 做什么…"
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch model.captureStatus {
        case .idle: EmptyView()
        case .sending: Text("发送中…").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
        case .sent: Text("已记录 ✓").font(.system(size: 10)).foregroundStyle(.green)
        case .failed: Text("失败,重试").font(.system(size: 10)).foregroundStyle(.red)
        }
    }

    private var dotColor: Color {
        switch model.connection {
        case .connected: .green
        case .disconnected: .red
        case .unknown: .yellow
        }
    }

    // MARK: Calendar helpers

    private var monthLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; f.locale = Locale(identifier: "en_US")
        return f.string(from: Date()).uppercased()
    }

    private func weekDays() -> [(offset: Int, weekday: String, number: Int, isToday: Bool)] {
        let cal = Calendar.current
        let today = Date()
        let letters = ["日", "一", "二", "三", "四", "五", "六"]
        guard let start = cal.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { i in
            guard let d = cal.date(byAdding: .day, value: i, to: start) else { return nil }
            let wd = cal.component(.weekday, from: d) - 1
            return (i, letters[wd], cal.component(.day, from: d), cal.isDateInToday(d))
        }
    }
}

/// The notch silhouette: top edge flush with the screen, small concave corners
/// where it meets the notch, large bottom radius — grows out of the notch.
struct NotchShape: Shape {
    var topConcave: CGFloat = 9
    var bottomRadius: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let tc = min(topConcave, w / 2)
        let br = min(bottomRadius, (w - 2 * tc) / 2, h - tc)
        p.move(to: CGPoint(x: 0, y: 0))
        p.addQuadCurve(to: CGPoint(x: tc, y: tc), control: CGPoint(x: tc, y: 0))
        p.addLine(to: CGPoint(x: tc, y: h - br))
        p.addQuadCurve(to: CGPoint(x: tc + br, y: h), control: CGPoint(x: tc, y: h))
        p.addLine(to: CGPoint(x: w - tc - br, y: h))
        p.addQuadCurve(to: CGPoint(x: w - tc, y: h - br), control: CGPoint(x: w - tc, y: h))
        p.addLine(to: CGPoint(x: w - tc, y: tc))
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w - tc, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - Collapsed glyphs

/// A small dancing equalizer — the "now playing" sign in the left slot.
private struct EqualizerBars: View {
    var color: Color
    @State private var animate = false
    private let heights: [CGFloat] = [11, 6, 12, 8]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule().fill(color)
                    .frame(width: 2, height: animate ? heights[i] : 3)
                    .animation(.easeInOut(duration: 0.4 + Double(i) * 0.08)
                        .repeatForever(autoreverses: true), value: animate)
            }
        }
        .frame(height: 12, alignment: .bottom)
        .onAppear { animate = true }
    }
}

/// Open Island-style status glyph for the right slot: three bars + a count whose
/// motion and color say the state (green dancing = running, amber pulsing = waiting).
private struct StatusGlyph: View {
    enum Kind { case running, waiting }
    var state: Kind
    var count: Int
    @State private var animate = false

    private var color: Color { state == .running ? .green : .orange }

    var body: some View {
        HStack(spacing: 6) {
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(color)
                        .frame(width: 2.5, height: barHeight(i))
                        .opacity(barOpacity(i))
                        .animation(barAnimation(i), value: animate)
                }
            }
            .frame(height: 13)
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(state == .waiting ? color : .white)
                .monospacedDigit()
        }
        .onAppear { animate = true }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        switch state {
        case .running: animate ? [9, 5, 11][i] : 4
        case .waiting: i == 1 ? 4 : 11
        }
    }
    private func barOpacity(_ i: Int) -> Double {
        guard state == .waiting else { return 1 }
        if i == 1 { return 0.4 }
        return animate ? 1 : 0.5
    }
    private func barAnimation(_ i: Int) -> Animation {
        switch state {
        case .running: .easeInOut(duration: 0.42 + Double(i) * 0.08).repeatForever(autoreverses: true)
        case .waiting: .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
        }
    }
}

/// Breathing amber outline around the whole right slot when an agent is waiting.
private struct GlowPill: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 9).padding(.vertical, 3)
            .overlay(
                Capsule().stroke(Color.orange, lineWidth: 1)
                    .opacity(on ? 0.85 : 0.3))
            .shadow(color: .orange.opacity(on ? 0.3 : 0), radius: on ? 6 : 0)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

private extension View {
    func glowingPill() -> some View { modifier(GlowPill()) }
}
