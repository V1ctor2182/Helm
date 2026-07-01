import AppKit
import HelmNotchCore
import SwiftUI
import UniformTypeIdentifiers

/// The notch surface (A×D fusion). Collapsed: two slots hugging the physical
/// notch, camera gap left clear. Hover → expand into a fixed 2×2 panel
/// (媒体 ↖ · 日历 ↗ · 本机 agent ↙ · 速记 ↘). The grid never deforms; the active
/// cell "comes alive": 速记 locks the panel for keyboard input, an agent waiting
/// on permission lights its cell. Accent color rotates daily.
struct NotchView: View {
    @Bindable var model: NotchModel
    @FocusState private var captureFocused: Bool
    @State private var dragOver = false

    private var accent: Color { Color(model.accent) }

    private let collapsedBarHeight: CGFloat = 32
    private var collapsedWidth: CGFloat { CGFloat(model.notchWidth) + 150 }

    var body: some View {
        // Banner states override collapsed/expanded. Reminder (560×152) takes
        // precedence over a permission request (620×208) — matching HTML render().
        let waiting = model.localSessions.first(where: { $0.needsAttention })
        let reminder = model.reminder
        let shellW: CGFloat = reminder != nil ? 560 : (waiting != nil ? 620 : (model.expanded ? model.expandedWidth : collapsedWidth))
        let shellH: CGFloat = reminder != nil ? 152 : (waiting != nil ? 208 : (model.expanded ? model.autoExpandedHeight : collapsedBarHeight))
        shell(width: shellW, height: shellH, banner: waiting, reminder: reminder)
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
    private func shell(width: CGFloat, height: CGFloat, banner: LocalSession? = nil, reminder: EventReminder? = nil) -> some View {
        ZStack(alignment: .top) {
            if let reminder {
                remindBanner(reminder)
            } else if let banner {
                permissionBanner(banner)
            } else {
                collapsedBar
                    .opacity(model.expanded ? 0 : 1)
                    .animation(.easeOut(duration: model.expanded ? 0.12 : 0.22), value: model.expanded)

                expandedPanel
                    .frame(width: model.expandedWidth, height: model.autoExpandedHeight, alignment: .top)
                    .opacity(model.expanded ? 1 : 0)
                    .offset(y: model.expanded ? 0 : -10)
                    .allowsHitTesting(model.expanded)
                    .animation(.easeOut(duration: 0.3).delay(model.expanded ? 0.12 : 0), value: model.expanded)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        .background(materialBackground)
        .clipShape(NotchShape(bottomRadius: model.expanded ? 24 : 16))
        // Drag a file onto the notch → stage it in 速记 (HTML notch.drag + drop).
        .overlay {
            if dragOver {
                NotchShape(bottomRadius: model.expanded ? 24 : 16)
                    .stroke(accent.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .padding(6)
            }
        }
        .overlay(alignment: .bottomTrailing) { if model.expanded { resizeHandle } }
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            for p in providers {
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in model.addFiles([url.lastPathComponent]) }
                }
            }
            return true
        }
        .onHover { model.hover($0) }
        // iOS-style shell grow (content has its own, delayed, animations above).
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.5), value: model.expanded)
        // Animate the height re-flow when the active view changes (HTML --eh transition).
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.42), value: model.autoExpandedHeight)
        .frame(maxWidth: .infinity, alignment: .top)  // center the shell in the canvas
    }

    /// Notch background per the chosen material (HTML MATS). `.black` is the
    /// default solid look; glass options blur the wallpaper behind the panel.
    @ViewBuilder private var materialBackground: some View {
        switch model.backgroundMaterial {
        case .black:
            Color.black
        case .darkGlass:
            Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.4))
        case .lightGlass:
            Rectangle().fill(.regularMaterial).overlay(Color.white.opacity(0.08))
        case .vibrant:
            Rectangle().fill(.ultraThinMaterial).overlay(Color(red: 0.09, green: 0.10, blue: 0.16).opacity(0.5))
        }
    }

    // MARK: Collapsed — one continuous bar (left content · camera gap · right glyph)

    private var collapsedBar: some View {
        HStack(spacing: 0) {
            collapsedLeft
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 11)
            // Physical notch / camera gap, with the HTML camera lens dot.
            Color.clear.frame(width: CGFloat(model.notchWidth))
                .overlay(alignment: .top) {
                    Circle().fill(Color(white: 0.05))
                        .overlay(Circle().stroke(Color(white: 0.17), lineWidth: 1))
                        .frame(width: 7, height: 7).padding(.top, 8)
                }
            collapsedRight
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 11)
        }
        .frame(width: collapsedWidth, height: collapsedBarHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    @ViewBuilder private var collapsedLeft: some View {
        if model.focusOn {
            HStack(spacing: 6) {
                Image(systemName: "timer").font(.system(size: 11)).foregroundStyle(accent)
                Text(model.focusWhat).font(.system(size: 10, weight: .medium)).foregroundStyle(.white).lineLimit(1)
            }
        } else if let np = model.nowPlaying {
            HStack(spacing: 6) {
                collapsedArt(np)
                if np.isPlaying {
                    EqualizerBars(color: accent)
                } else {
                    Image(systemName: "pause.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
                }
                Text(np.title).font(.system(size: 10)).foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1).frame(maxWidth: 90, alignment: .leading)
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
        if model.focusOn {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let s = model.focusElapsed(at: context.date)
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 6, height: 6)
                    Text(String(format: "%02d:%02d", s / 60, s % 60))
                        .font(.system(size: 12, weight: .bold)).monospacedDigit().foregroundStyle(accent)
                }
            }
        } else if waiting > 0 {
            // HTML: orange ● + count (an actual waiting agent pops the banner anyway).
            HStack(spacing: 5) {
                Circle().fill(.orange).frame(width: 7, height: 7)
                Text("\(waiting)").font(.system(size: 11, weight: .bold)).foregroundStyle(.orange).monospacedDigit()
            }
        } else if running > 0 {
            // HTML: spinning ✻ star + count.
            HStack(spacing: 5) {
                SpinningStar(color: accent)
                Text("\(running)").font(.system(size: 11, weight: .bold)).foregroundStyle(.white).monospacedDigit()
            }
        } else if let ev = model.events.first {
            // HTML cev: next event "10:00 站会" (accent time + name).
            HStack(spacing: 5) {
                Text(ev.when).font(.system(size: 10, weight: .bold)).foregroundStyle(accent).monospacedDigit()
                Text(ev.summary).font(.system(size: 10)).foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1).frame(maxWidth: 80, alignment: .leading)
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

    // MARK: Expanded — dock + module router (ported from helm-notch-pro.html #panel)
    //
    // TODO(align): pending [needs-human] 3edd9817 — this dock+module shell
    // supersedes the fixed 2×2 `grid` above (kept for rollback). Once confirmed,
    // delete `grid`/`cell`/`vline`/`hline`/`topControls`.

    /// `#panel`: top bar (logo · gear) → switchable module view → dock.
    private var expandedPanel: some View {
        VStack(spacing: 0) {
            topBar
            moduleBody
                .id(model.module)
                .transition(moduleTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.3), value: model.module)
            dockBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Directional slide (HTML slideTo): forward → new enters from the right and
    /// the old exits left; backward → the reverse.
    private var moduleTransition: AnyTransition {
        let f = model.moduleSwitchForward
        return .asymmetric(
            insertion: .move(edge: f ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: f ? .leading : .trailing).combined(with: .opacity))
    }

    /// `.ntop` — Helm wordmark on the left, an X (when locked) + gear on the right.
    private var topBar: some View {
        HStack(spacing: 7) {
            logoMark
            Text("Helm").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            Spacer()
            if model.locked {
                Button { model.collapse() } label: {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain).foregroundStyle(.white.opacity(0.45))
            }
            Button { model.openSettings?() } label: {
                Image(systemName: "gearshape").font(.system(size: 13)).fontWeight(.regular)
            }
            .buttonStyle(.plain).foregroundStyle(.white.opacity(0.56))
        }
        .frame(height: 30)
        .padding(.horizontal, 13)
    }

    /// The HTML logo SVG: an accent rounded square with a dark "H" (`M8 7.5v9 M16 7.5v9 M8 12h8`).
    private var logoMark: some View {
        let dark = Color(red: 0.043, green: 0.055, blue: 0.059)
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(accent)
            .frame(width: 16, height: 16)
            .overlay {
                ZStack {
                    HStack(spacing: 4) {
                        Capsule().fill(dark).frame(width: 2, height: 9)
                        Capsule().fill(dark).frame(width: 2, height: 9)
                    }
                    Capsule().fill(dark).frame(width: 8, height: 2)
                }
            }
    }

    /// `.dock` — the five module glyphs; the active one rings in accent, Dev
    /// shows an orange badge when a local agent is waiting on permission.
    private var dockBar: some View {
        HStack(spacing: 9) {
            ForEach(NotchModule.dock) { m in dockButton(m) }
        }
        .padding(.top, 8).padding(.bottom, 9)
        .frame(maxWidth: .infinity)
    }

    private func dockButton(_ m: NotchModule) -> some View {
        let on = model.module == m
        let badge = (m == .dev && model.localAttentionCount > 0)
        return Button { model.selectModule(m) } label: {
            Text(m.glyph)
                .font(.system(size: 14))
                .foregroundStyle(on ? accent : .white.opacity(0.56))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(white: on ? 0.17 : 0.10)))
                .overlay(Circle().stroke(accent, lineWidth: on ? 1.5 : 0))
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle().fill(Color.orange).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                            .offset(x: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// `.view` — one module at a time. Reuses the 2×2 cell bodies as interim
    /// content for capture/calendar/dev/media; dashboard + clipboard are ported here.
    @ViewBuilder private var moduleBody: some View {
        switch model.module {
        case .dashboard:
            dashboardModule.padding(.top, 12)
        case .capture:
            moduleScroll { captureCell }
        case .calendar:
            calendarModule
        case .dev:
            devModule
        case .clipboard:
            moduleScroll { clipboardBody }
        case .media:
            mediaModule
        }
    }

    private func moduleScroll<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.top, 14).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Dashboard module (V.dash — three widgets: NOW PLAYING · TODAY · 本机 CLAUDE CODE)

    private var dashboardModule: some View {
        GeometryReader { geo in
            let unit = geo.size.width / 3.6  // widget flex 1.6 : 1 : 1
            HStack(spacing: 0) {
                dashMediaWidget
                    .frame(width: unit * 1.6, alignment: .topLeading)
                    .overlay(alignment: .trailing) { dashColDivider }
                dashTodayWidget
                    .frame(width: unit, alignment: .topLeading)
                    .overlay(alignment: .trailing) { dashColDivider }
                dashAgentWidget
                    .frame(width: unit, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var dashColDivider: some View { Rectangle().fill(.white.opacity(0.09)).frame(width: 1) }

    private func dashHeader(_ title: String) -> some View {
        Text(title).font(.system(size: 9, weight: .bold)).tracking(0.6)
            .foregroundStyle(.white.opacity(0.34)).padding(.bottom, 12)
    }

    private var dashMediaWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            dashHeader("NOW PLAYING")
            if let np = model.nowPlaying {
                HStack(spacing: 12) {
                    dashCover(np).frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(np.title).font(.system(size: 12, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                        Text(np.subtitle.isEmpty ? " " : np.subtitle).font(.system(size: 10)).foregroundStyle(.white.opacity(0.56)).lineLimit(1)
                        dashMiniBar(np).padding(.top, 6)
                        HStack(spacing: 16) {
                            Button { model.previousTrack() } label: { Image(systemName: "backward.fill") }
                            Button { model.playPause() } label: { Image(systemName: np.isPlaying ? "pause.fill" : "play.fill") }
                            Button { model.nextTrack() } label: { Image(systemName: "forward.fill") }
                        }
                        .font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(.white).padding(.top, 8)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    dashCover(nil).frame(width: 64, height: 64)
                    Text("未在播放").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 2)
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { model.selectModule(.media) }
    }

    private func dashCover(_ np: NowPlaying?) -> some View {
        Group {
            if let np, let art = nsArtwork(np) {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(red: 0.11, green: 0.72, blue: 0.33), Color(red: 0.04, green: 0.5, blue: 0.23)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private func dashMiniBar(_ np: NowPlaying) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let total = np.duration ?? 0
            let frac = total > 0 ? min(1, model.livePosition(at: context.date) / total) : 0.42
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule().fill(accent).frame(width: max(2, geo.size.width * frac))
                }
            }
            .frame(height: 3)
        }
        .frame(height: 3)
    }

    private var dashTodayWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            dashHeader("TODAY")
            HStack(spacing: 13) {
                dashDonut
                VStack(alignment: .leading, spacing: 6) {
                    if model.events.isEmpty {
                        dashTaskRow(.green, "站会 10:00")
                        dashTaskRow(Color(red: 0.04, green: 0.52, blue: 1), "Review")
                        dashTaskRow(.orange, "1:1 15:00")
                    } else {
                        ForEach(Array(model.events.prefix(3))) { ev in
                            dashTaskRow(accent, "\(ev.summary) \(ev.when)")
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 2)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Static demo donut (HTML shows "3/11"); real task counts need backend.
    // TODO(align): wire to task completion once Core surfaces it.
    private var dashDonut: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.12), lineWidth: 7)
            Circle().trim(from: 0, to: 0.27).stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                .rotationEffect(.degrees(-90))
            Text("3/11").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
        }
        .frame(width: 54, height: 54)
    }

    private func dashTaskRow(_ dot: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(text).font(.system(size: 11)).foregroundStyle(.white.opacity(0.56)).lineLimit(1)
        }
    }

    private var dashAgentWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            dashHeader("本机 CLAUDE CODE")
            if model.localSessions.isEmpty {
                Text("无 agent").font(.system(size: 11)).foregroundStyle(.white.opacity(0.34))
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(model.localSessions.prefix(3))) { s in
                        HStack(spacing: 7) {
                            Circle().fill(phaseColor(s.phase)).frame(width: 7, height: 7)
                            Text(s.folderName).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                            if s.phase == .waitingPermission {
                                Text("待批准").font(.system(size: 10)).foregroundStyle(.orange)
                            } else if s.phase == .running {
                                ShineText(s.activity ?? "思考中", accent: accent, size: 10)
                            } else if s.phase == .ended {
                                Text("完成").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 2)
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onTapGesture { model.selectModule(.dev) }
    }

    // MARK: Calendar module (V.cal — header · week strip ⇄ month grid · agenda)

    private let calWeekLabels = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]

    /// The month currently shown (this month + `calMonthOffset`).
    private var calDisplayMonth: Date {
        let cal = Calendar.current
        let firstOfThis = cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
        return cal.date(byAdding: .month, value: model.calMonthOffset, to: firstOfThis) ?? firstOfThis
    }

    private func calMonthName(_ d: Date, short: Bool = false) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US"); f.dateFormat = short ? "MMM" : "MMMM"
        return f.string(from: d)
    }

    private var calendarModule: some View {
        let cal = Calendar.current
        let dm = calDisplayMonth
        return VStack(spacing: 0) {
            // calhd2 — month/year · Today · view toggle · ‹ ›
            HStack(spacing: 7) {
                Text(calMonthName(dm)).font(.system(size: 17, weight: .heavy)).foregroundStyle(.white)
                Text("\(cal.component(.year, from: dm))").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.34))
                if model.calMonthOffset != 0 {
                    Button { model.calToday() } label: {
                        Text("Today").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.56))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }.buttonStyle(.plain)
                }
                Spacer()
                HStack(spacing: 2) {
                    calSegButton(systemImage: "square.grid.2x2.fill", on: model.calMonthView) { model.calSetMonthView(true) }
                    calSegButton(systemImage: "line.3.horizontal", on: !model.calMonthView) { model.calSetMonthView(false) }
                }
                .padding(2).background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.06)))
                HStack(spacing: 5) {
                    calNavButton("chevron.left") { model.calPrevMonth() }
                    calNavButton("chevron.right") { model.calNextMonth() }
                }
            }
            .padding(.bottom, 11)

            // calbody — left (week/month) · right (agenda)
            HStack(spacing: 14) {
                Group {
                    if model.calMonthView { calMonthGrid(dm) } else { calWeekStrip(dm) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                calAgenda(dm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 14)
                    .overlay(alignment: .leading) { Rectangle().fill(.white.opacity(0.09)).frame(width: 0.5) }
            }
        }
        .padding(.top, 14).padding(.horizontal, 16).padding(.bottom, 10)
    }

    private func calSegButton(systemImage: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 10))
                .foregroundStyle(on ? Color(red: 0.1, green: 0.07, blue: 0.03) : .white.opacity(0.56))
                .frame(width: 25, height: 22)
                .background { if on { RoundedRectangle(cornerRadius: 7).fill(accent) } }
        }.buttonStyle(.plain)
    }

    private func calNavButton(_ systemImage: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.56))
                .frame(width: 24, height: 24).background(Circle().fill(.white.opacity(0.06)))
        }.buttonStyle(.plain)
    }

    // Week strip (S.calExpand=false): big month/year + 7 day columns.
    private func calWeekStrip(_ dm: Date) -> some View {
        let cal = Calendar.current
        let today = Date()
        // Week containing today (offset 0) or the 1st of the displayed month.
        let base = model.calMonthOffset == 0 ? today : dm
        let weekdayMon0 = (cal.component(.weekday, from: base) + 5) % 7
        let weekStart = cal.date(byAdding: .day, value: -weekdayMon0, to: base) ?? base
        let dmMonth = cal.component(.month, from: dm)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(calMonthName(dm, short: true)).font(.system(size: 30, weight: .heavy)).foregroundStyle(.white)
                Text("\(cal.component(.year, from: dm))").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.34))
            }
            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { i in
                    let d = cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart
                    let day = cal.component(.day, from: d)
                    let inMonth = cal.component(.month, from: d) == dmMonth
                    let isToday = cal.isDateInToday(d)
                    let selected = inMonth && day == model.calSelectedDay
                    VStack(spacing: 6) {
                        Text(calWeekLabels[i]).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.34))
                        Text("\(day)").font(.system(size: 21, weight: .heavy)).foregroundStyle(isToday ? accent : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if isToday { RoundedRectangle(cornerRadius: 13).fill(.white.opacity(0.06)) }
                        else if selected { RoundedRectangle(cornerRadius: 13).stroke(accent, lineWidth: 1.5) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if inMonth { model.calSelectDay(day) } }
                }
            }
        }
    }

    // Month grid (S.calExpand=true): MON..SUN header + 6 weeks with a month rail.
    private func calMonthGrid(_ dm: Date) -> some View {
        let cal = Calendar.current
        let dmMonth = cal.component(.month, from: dm)
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: dm)) ?? dm
        let weekdayMon0 = (cal.component(.weekday, from: firstOfMonth) + 5) % 7
        let gridStart = cal.date(byAdding: .day, value: -weekdayMon0, to: firstOfMonth) ?? firstOfMonth
        return VStack(spacing: 5) {
            HStack(spacing: 0) {
                Color.clear.frame(width: 30)
                ForEach(calWeekLabels, id: \.self) { w in
                    Text(w).font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.34)).frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<6, id: \.self) { r in
                let rowStart = cal.date(byAdding: .day, value: r * 7, to: gridStart) ?? gridStart
                let prevRowMonth = r == 0 ? -1 : cal.component(.month, from: cal.date(byAdding: .day, value: (r - 1) * 7, to: gridStart) ?? gridStart)
                let rowMonth = cal.component(.month, from: rowStart)
                HStack(spacing: 0) {
                    calMonthRail(rowStart, show: rowMonth != prevRowMonth, isCurrent: rowMonth == dmMonth).frame(width: 30)
                    ForEach(0..<7, id: \.self) { i in
                        let d = cal.date(byAdding: .day, value: i, to: rowStart) ?? rowStart
                        calMonthCell(d, displayedMonth: dmMonth)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func calMonthRail(_ d: Date, show: Bool, isCurrent: Bool) -> some View {
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: 2) {
            if show {
                Text(calMonthName(d, short: true).uppercased()).font(.system(size: 8, weight: .bold))
                    .foregroundStyle(isCurrent ? accent : .white.opacity(0.34))
                Text(String(format: "%02d", cal.component(.month, from: d))).font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(isCurrent ? accent : .white.opacity(0.56))
                if isCurrent { Circle().fill(accent).frame(width: 4, height: 4) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func calMonthCell(_ d: Date, displayedMonth: Int) -> some View {
        let cal = Calendar.current
        let day = cal.component(.day, from: d)
        let out = cal.component(.month, from: d) != displayedMonth
        let isToday = cal.isDateInToday(d)
        let selected = !out && day == model.calSelectedDay
        return ZStack {
            if isToday { Circle().fill(.white).frame(width: 26, height: 26) }
            else if selected { Circle().stroke(accent, lineWidth: 1.5).frame(width: 26, height: 26) }
            Text("\(day)")
                .font(.system(size: 12.5, weight: isToday ? .heavy : .semibold))
                .foregroundStyle(isToday ? Color(red: 0.05, green: 0.06, blue: 0.07) : (out ? .white.opacity(0.2) : .white.opacity(0.86)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if !out { model.calSelectDay(day) } }
    }

    // Agenda (calR): selected-day header + events. Per-day events need a backend
    // date-range query; for now today's events show, other days are empty.
    // TODO(align-cal): wire per-day events once the backend exposes them.
    private func calAgenda(_ dm: Date) -> some View {
        let cal = Calendar.current
        let isToday = model.calMonthOffset == 0 && model.calSelectedDay == cal.component(.day, from: Date())
        let events = isToday ? model.events : []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(isToday ? "今天 · " : "")\(cal.component(.month, from: dm))月\(model.calSelectedDay)日")
                    .font(.system(size: 13, weight: .heavy)).foregroundStyle(.white)
                Spacer()
                Text(events.isEmpty ? "无安排" : "\(events.count) 项").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
            }
            .padding(.bottom, 4)
            if events.isEmpty {
                VStack(spacing: 9) {
                    Spacer()
                    Text("这天没有安排").font(.system(size: 12)).foregroundStyle(.white.opacity(0.34))
                    Text("＋ 到 Helm 新建").font(.system(size: 12)).foregroundStyle(accent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(events) { ev in
                        HStack(alignment: .top, spacing: 11) {
                            Text(ev.when).font(.system(size: 12, weight: .heavy)).foregroundStyle(accent)
                                .frame(width: 44, alignment: .leading).monospacedDigit()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ev.summary).font(.system(size: 13, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Circle().fill(accent).frame(width: 7, height: 7).padding(.top, 5)
                        }
                        .padding(.vertical, 9)
                        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5) }
                    }
                }
            }
        }
    }

    // MARK: Dev module (V.dev — vertical rail paging agents/ports/reviews/stats)

    /// `.devwrap` — the current sub-page on the left, a minimal vertical pager
    /// rail on the right. The rail dot for the active section elongates in accent.
    private var devModule: some View {
        HStack(spacing: 6) {
            devStage
                .id(model.devSection)
                .transition(devTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.3), value: model.devSection)
            devRail
        }
        .padding(.top, 14).padding(.horizontal, 16).padding(.bottom, 6)
    }

    /// Vertical slide (HTML slideDev): down → new enters from the bottom.
    private var devTransition: AnyTransition {
        let f = model.devSwitchForward
        return .asymmetric(
            insertion: .move(edge: f ? .bottom : .top).combined(with: .opacity),
            removal: .move(edge: f ? .top : .bottom).combined(with: .opacity))
    }

    @ViewBuilder private var devStage: some View {
        switch model.devSection {
        case .agents: VStack(alignment: .leading, spacing: 0) { agentCell }
        case .ports: devPorts
        case .reviews: devReviews
        case .stats: devStats
        }
    }

    private var devRail: some View {
        VStack(spacing: 9) {
            ForEach(DevSection.allCases) { s in
                let on = model.devSection == s
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(on ? accent : .white.opacity(0.22))
                    .frame(width: 5, height: on ? 18 : 5)
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectDev(s) }
            }
        }
        .frame(width: 20)
        .frame(maxHeight: .infinity)
    }

    // Ports (V.ports). TODO(align-dev-ports): real list needs an lsof probe.
    private let portSeed: [(port: Int, name: String, color: Color)] = [
        (3000, "Frontend · next dev", .green),
        (8769, "Helm backend · python", .green),
        (5173, "Vite · docs", .green),
        (11434, "Ollama", .orange),
        (6006, "Storybook", .green),
    ]

    private var devPorts: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader("本地端口 · LISTENING", trailing: "lsof -iTCP -sTCP:LISTEN")
            ForEach(portSeed.indices, id: \.self) { i in
                let p = portSeed[i]
                HStack(spacing: 11) {
                    Circle().fill(p.color).frame(width: 7, height: 7)
                    Text(":\(p.port)").font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white).frame(minWidth: 56, alignment: .leading)
                    Text(p.name).font(.system(size: 12)).foregroundStyle(.white.opacity(0.56)).lineLimit(1)
                    Spacer(minLength: 6)
                    Text("↗ 打开").font(.system(size: 10)).foregroundStyle(accent)
                }
                .padding(.vertical, 7)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5) }
            }
            Spacer(minLength: 0)
        }
    }

    // Reviews (V.prs). TODO(align-dev-reviews): real list needs a GitHub/GitLab probe.
    private let prSeed: [(who: String, title: String, repo: String, num: String, src: String)] = [
        ("VZ", "feat(notch): 日程提醒 banner + 波形", "V1ctor2182/Helm", "#51", "GH"),
        ("VZ", "fix(notch): AppDelegate @MainActor + @Sendable", "V1ctor2182/Helm", "#50", "GH"),
        ("BP", "Resolve \"Implement integration test\"", "helm/bridge", "#123", "GL"),
    ]

    private var devReviews: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader("◈ 待评审 · PRs / MRs", trailing: "\(prSeed.count) 待处理")
            ForEach(prSeed.indices, id: \.self) { i in
                let p = prSeed[i]
                HStack(spacing: 10) {
                    Text(p.who).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.56))
                        .frame(width: 26, height: 26).background(Circle().fill(Color(white: 0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                        HStack(spacing: 6) {
                            Text("\(p.repo) \(p.num)").font(.system(size: 10)).foregroundStyle(.white.opacity(0.56)).lineLimit(1)
                            Text(p.src).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.34))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.07)))
                        }
                    }
                    Spacer(minLength: 4)
                    Text("↗").font(.system(size: 13)).foregroundStyle(accent)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) {
                    if i < prSeed.count - 1 { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5) }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // Stats (V.stats). TODO(align-dev-stats): heatmap/tokens/commits are seed
    // data — real numbers need GitHub + Claude-Code token tracking.
    private let sparkSeed: [Int] = [38, 62, 30, 78, 52, 88, 68]

    private var devStats: some View {
        GeometryReader { geo in
            let heatW = (geo.size.width - 18) * 1.45 / 2.45
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 0) {
                    cellHeader("GITHUB · 1,284 contributions")
                    heatmap.padding(.top, 4)
                    HStack(spacing: 3) {
                        Text("Less").font(.system(size: 9)).foregroundStyle(.white.opacity(0.34))
                        ForEach(1..<5) { l in RoundedRectangle(cornerRadius: 2).fill(accent).opacity(heatOpacity(l)).frame(width: 9, height: 9) }
                        Text("More").font(.system(size: 9)).foregroundStyle(.white.opacity(0.34))
                    }
                    .padding(.top, 8)
                }
                .frame(width: heatW, alignment: .leading)

                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("CLAUDE CODE TOKENS · TODAY").font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundStyle(.white.opacity(0.34))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            (Text("2.4").font(.system(size: 24, weight: .heavy)) + Text("M").font(.system(size: 13)).foregroundColor(.white.opacity(0.56)))
                                .foregroundStyle(.white)
                            Text("· 48M 总").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.34))
                        }
                        .padding(.top, 3)
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(sparkSeed.indices, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2).fill(accent).opacity(0.85)
                                    .frame(maxWidth: .infinity).frame(height: CGFloat(sparkSeed[i]) / 100 * 24)
                            }
                        }
                        .frame(height: 24).padding(.top, 8)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.09), lineWidth: 0.5))

                    HStack(spacing: 10) {
                        statMini("COMMITS · 本周", value: "37")
                        statMini("PULL REQUESTS", value: "3 open · 12")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func statMini(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, weight: .bold)).tracking(0.5).foregroundStyle(.white.opacity(0.34))
            Text(value).font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).lineLimit(1)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.09), lineWidth: 0.5))
    }

    /// `.hmap` — 19 columns × 7 rows; level→opacity from a deterministic hash
    /// (HTML seeds it with Math.random; we use a stable hash for reproducibility).
    private var heatmap: some View {
        HStack(spacing: 3) {
            ForEach(0..<19, id: \.self) { col in
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { row in
                        RoundedRectangle(cornerRadius: 2).fill(accent)
                            .opacity(heatOpacity(heatLevel(col * 7 + row)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
    }

    private func heatLevel(_ i: Int) -> Int {
        let r = heatHash(i)
        return r < 0.4 ? 0 : r < 0.62 ? 1 : r < 0.82 ? 2 : r < 0.94 ? 3 : 4
    }
    private func heatOpacity(_ level: Int) -> Double { [0.09, 0.3, 0.52, 0.74, 1.0][level] }
    private func heatHash(_ i: Int) -> Double {
        let x = sin(Double(i) * 12.9898 + 78.233) * 43758.5453
        return x - floor(x)
    }

    // MARK: Media module (V.media / .mfull — blurred cover · cover/lyrics · waveform)
    //
    // TODO(align-media-height): HTML `VH.media`=330 — per-view auto-height isn't
    // ported yet; this renders within the current resizable panel height.

    private let lyricsDemo = [
        "I've been walking through the storm",
        "Counting every blessing as it comes",
        "Even when the night feels long",
        "I know the morning's gonna come",
        "So I'll keep counting my blessings",
        "One by one by one",
    ]

    private var mediaModule: some View {
        let np = model.nowPlaying
        let title = np?.title ?? "Counting My Blessings"
        let artist = (np.map { $0.artist.isEmpty ? "Seph Schlueter" : $0.artist }) ?? "Seph Schlueter"
        return ZStack {
            mediaBgCover
            VStack(spacing: 0) {
                HStack {
                    Button { model.selectModule(.dashboard) } label: {
                        Text("‹ 返回").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.56))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button { model.cycleMediaSource() } label: {
                        HStack(spacing: 6) {
                            Circle().fill(accent).frame(width: 7, height: 7)
                            Text(model.mediaSource.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.56))
                            Text("⌄").font(.system(size: 9)).foregroundStyle(.white.opacity(0.34))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 3)

                HStack(spacing: 22) {
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer(minLength: 0)
                        coverArt(np, size: 84, radius: 14)
                            .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                        Text(title).font(.system(size: 14, weight: .heavy)).foregroundStyle(.white).lineLimit(1).padding(.top, 8)
                        Text(artist).font(.system(size: 11)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                        mediaProgress(np).padding(.top, 9)
                        HStack(spacing: 22) {
                            Button { model.previousTrack() } label: { Image(systemName: "backward.fill").font(.system(size: 15)) }
                            Button { model.playPause() } label: { Image(systemName: (np?.isPlaying ?? true) ? "pause.fill" : "play.fill").font(.system(size: 21)) }
                            Button { model.nextTrack() } label: { Image(systemName: "forward.fill").font(.system(size: 15)) }
                        }
                        .buttonStyle(.plain).foregroundStyle(.white).padding(.top, 8)
                        Spacer(minLength: 0)
                    }
                    .frame(width: 190)
                    lyricsColumn
                }
                .frame(maxHeight: .infinity)

                Waveform(playing: np?.isPlaying ?? true, color: accent)
                    .frame(height: 24).padding(.top, 7)
            }
            .padding(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// `.bgcov` — the cover blurred + scaled behind everything, with a dark scrim.
    private var mediaBgCover: some View {
        ZStack {
            Group {
                if let np = model.nowPlaying, let art = nsArtwork(np) {
                    Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.91, green: 0.63, blue: 0.48), Color(red: 0.71, green: 0.42, blue: 0.56), Color(red: 0.42, green: 0.31, blue: 0.56)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .blur(radius: 34).scaleEffect(1.3).opacity(0.6)
            Color.black.opacity(0.45)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private func coverArt(_ np: NowPlaying?, size: CGFloat, radius: CGFloat) -> some View {
        Group {
            if let np, let art = nsArtwork(np) {
                Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(red: 0.11, green: 0.72, blue: 0.33), Color(red: 0.04, green: 0.5, blue: 0.23)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// `.mbar2` — real progress when known; otherwise the HTML's static 42% demo.
    @ViewBuilder private func mediaProgress(_ np: NowPlaying?) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let total = np?.duration ?? 0
            let pos = model.livePosition(at: context.date)
            let frac = total > 0 ? min(1, pos / total) : 0.42
            VStack(spacing: 3) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white).frame(width: max(2, geo.size.width * frac))
                        Circle().fill(.white).frame(width: 10, height: 10)
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                            .offset(x: max(0, geo.size.width * frac - 5))
                    }
                }
                .frame(height: 10)
                HStack {
                    Text(total > 0 ? timeString(pos) : "0:42"); Spacer(); Text(total > 0 ? timeString(total) : "1:31")
                }
                .font(.system(size: 9)).foregroundStyle(.white.opacity(0.55)).monospacedDigit()
            }
        }
    }

    /// `.lyrics` — scrolling lyrics with the current line lit, masked top/bottom.
    /// TODO(align-media): demo lyrics; real synced lyrics need a provider.
    private var lyricsColumn: some View {
        TimelineView(.periodic(from: .now, by: 2.6)) { context in
            let playing = model.nowPlaying?.isPlaying ?? true
            let cur = playing ? Int(context.date.timeIntervalSince1970 / 2.6) % lyricsDemo.count : 2
            VStack(alignment: .leading, spacing: 7) {
                ForEach(lyricsDemo.indices, id: \.self) { i in
                    Text(lyricsDemo[i])
                        .font(.system(size: i == cur ? 14 : 13, weight: i == cur ? .bold : .regular))
                        .foregroundStyle(i == cur ? .white : .white.opacity(0.38))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .mask(LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.22),
                        .init(color: .black, location: 0.78), .init(color: .clear, location: 1)],
                startPoint: .top, endPoint: .bottom))
        }
    }

    // MARK: Clipboard module (V.clip) — seed data; real history is a later block.

    /// HTML `CLIP` seed. TODO(align-clipboard): replace with a Core clipboard
    /// model fed by an NSPasteboard watcher.
    private var clipboardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            cellHeader("⧉ CLIPBOARD 历史", trailing: "点→复制 / 存速记")
            ForEach(clipSeed.indices, id: \.self) { i in
                let c = clipSeed[i]
                HStack(spacing: 9) {
                    Text(c.0).font(.system(size: 13))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 7).fill(Color(white: 0.10)))
                    Text(c.1).font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                    Spacer(minLength: 6)
                    Text(c.2).font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.09)).frame(height: 0.5) }
            }
            Spacer(minLength: 0)
        }
    }

    private let clipSeed: [(String, String, String)] = [
        ("↗", "https://github.com/V1ctor2182/Helm/pull/50", "just now"),
        ("≡", "feat(notch): A×D 2×2 面板重做…", "5m"),
        ("#", "127.0.0.1:8769", "12m"),
        ("▣", "Screenshot 2026-06-29.png", "20m"),
    ]

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
                    if session.phase == .running {
                        SpinningStar(color: accent).scaleEffect(0.78)
                        ShineText(session.activity ?? "正在思考…", accent: accent, size: 10)
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

    // MARK: Permission banner (HTML bannerHTML — pops on waiting_permission)
    //
    // TODO(align-banner): HTML shows a code diff; the hook only sends tool/detail
    // for now, so the request body shows that instead of a real diff.

    private func permissionBanner(_ s: LocalSession) -> some View {
        let amber = Color(red: 1, green: 0.85, blue: 0.64)
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(.orange).frame(width: 7, height: 7)
                    Text("Permission Request · \(s.folderName)").font(.system(size: 11, weight: .bold)).foregroundStyle(amber)
                }
                Spacer()
                Text("⌘Y 允许 · ⌘N 拒绝").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
            }
            Text("⚠︎ \(s.pendingTool ?? "请求执行")").font(.system(size: 11, weight: .semibold)).foregroundStyle(amber).padding(.top, 10)
            Text(s.pendingDetail ?? s.pendingTool ?? "(请求权限)")
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.82))
                .lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 8).fill(.black.opacity(0.4)))
                .padding(.top, 9)
            HStack(spacing: 10) {
                Button { model.resolveLocalPermission(s.id, allow: false) } label: {
                    Text("Deny ⌘N").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.1)))
                }.buttonStyle(.plain)
                Button { model.resolveLocalPermission(s.id, allow: true) } label: {
                    Text("Allow ⌘Y").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.03))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent))
                }.buttonStyle(.plain)
            }
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18))
        .frame(width: 620, height: 208, alignment: .topLeading)
    }

    // MARK: Reminder banner (HTML remindHTML / .notch.remind — pops on a near event)
    //
    // TODO(align-remind): the HTML shows a meeting "加入" link + location; CalEvent
    // carries neither, so we show 查看 (→ Calendar) + 稍后 / 忽略 and the time range.

    private func remindBanner(_ r: EventReminder) -> some View {
        HStack(spacing: 17) {
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.09), lineWidth: 0.5))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "calendar").font(.system(size: 24)).foregroundStyle(accent))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(accent).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 3))
                    Text("日程提醒 · 现在开始").font(.system(size: 10, weight: .bold)).tracking(0.5).foregroundStyle(.white.opacity(0.56))
                }
                .padding(.bottom, 6)
                Text(r.title).font(.system(size: 18, weight: .heavy)).foregroundStyle(.white).lineLimit(1)
                Text(r.timeRange).font(.system(size: 12)).foregroundStyle(.white.opacity(0.56)).monospacedDigit().padding(.top, 3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 8) {
                Button { model.openReminder(); model.selectModule(.calendar); model.expanded = true } label: {
                    Text("查看").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.03))
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent))
                }.buttonStyle(.plain)
                HStack(spacing: 8) {
                    Button { model.snoozeReminder() } label: { remindSubLabel("稍后") }.buttonStyle(.plain)
                    Button { model.dismissReminder() } label: { remindSubLabel("忽略") }.buttonStyle(.plain)
                }
            }
            .frame(width: 132)
        }
        .padding(.horizontal, 22)
        .frame(width: 560, height: 152, alignment: .leading)
    }

    private func remindSubLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.56))
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.1)))
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
        if model.captureKind == .focus {
            focusBody.padding(.top, 10)
        } else {
            // 任务:给自己 / 交给 agent
            if model.captureKind == .task { taskTargetToggle.padding(.top, 8) }
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
            // 时间 / 地点 附件(note/task)
            if !model.captureFiles.isEmpty { captureFilesRow.padding(.top, 8) }
            // 时间/地点附件仅 note/task(HTML capatt 条件),ask/journal 不显示。
            if model.captureKind == .note || model.captureKind == .task { attachmentRow.padding(.top, 8) }
            statusLabel.padding(.top, 2)
            recentsSection.padding(.top, 6)
        }
        Spacer(minLength: 0)
    }

    /// 专注:未开始 = 输入「在做什么」+ 开始;进行中 = 大计时 + 停止并记录。
    @ViewBuilder private var focusBody: some View {
        if model.focusOn {
            VStack(spacing: 9) {
                Text("正在专注").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(.white.opacity(0.34))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let s = model.focusElapsed(at: context.date)
                    HStack(spacing: 11) {
                        Circle().fill(accent).frame(width: 10, height: 10)
                        Text(String(format: "%02d:%02d", s / 60, s % 60))
                            .font(.system(size: 42, weight: .heavy)).monospacedDigit().foregroundStyle(.white)
                    }
                }
                Text(model.focusWhat).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                Button { _ = model.stopFocus() } label: {
                    Text("停止并记录").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.03))
                        .padding(.horizontal, 22).padding(.vertical, 8)
                        .background(Capsule().fill(accent))
                }
                .buttonStyle(.plain)
                Text("停止时自动写入 Helm /api/focus").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                TextField("我现在在做什么…", text: $model.captureText)
                    .textFieldStyle(.plain).font(.system(size: 14)).foregroundStyle(.white)
                    .focused($captureFocused)
                    .onSubmit { model.startFocus() }
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06)))
                HStack {
                    Text("⏎ 开始 · 关掉时自动记录这段专注到 Helm").font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
                    Spacer()
                    Button { model.startFocus() } label: {
                        Text("开始专注").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.03))
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(Capsule().fill(accent))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 给自己 / 交给 agent (HTML .ttog). TODO(align-capture): agent path → Cockpit.
    private var taskTargetToggle: some View {
        HStack(spacing: 0) {
            ForEach(TaskTarget.allCases) { target in
                let on = model.taskTarget == target
                Button(target.label) { model.taskTarget = target }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Color(red: 0.1, green: 0.07, blue: 0.03) : .white.opacity(0.56))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background { if on { accent } }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.09), lineWidth: 0.5))
    }

    /// 拖入文件的附件 chip (HTML .attchip). Upload happens on send — TODO.
    private var captureFilesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.captureFiles) { f in
                    HStack(spacing: 7) {
                        Text(f.ext).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.56))
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(white: 0.10)))
                        Text(f.name).font(.system(size: 11)).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                            .frame(maxWidth: 120, alignment: .leading)
                        Button { model.removeFile(f.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 8)).foregroundStyle(.white.opacity(0.6))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.09), lineWidth: 0.5))
                }
            }
        }
    }

    /// 时间 / 地点 chips (HTML .capatt). Demo values; real pickers are a TODO.
    private var attachmentRow: some View {
        HStack(spacing: 7) {
            attachmentChip(systemImage: "clock", value: model.captureWhen,
                           add: { model.captureWhen = "今天 15:00" }, remove: { model.captureWhen = nil }, label: "时间")
            attachmentChip(systemImage: "mappin.and.ellipse", value: model.captureWhere,
                           add: { model.captureWhere = "Brooklyn, New York" }, remove: { model.captureWhere = nil }, label: "地点")
            Spacer(minLength: 0)
        }
    }

    private func attachmentChip(systemImage: String, value: String?, add: @escaping () -> Void, remove: @escaping () -> Void, label: String) -> some View {
        Group {
            if let value {
                HStack(spacing: 6) {
                    Image(systemName: systemImage).font(.system(size: 10)).foregroundStyle(accent)
                    Text(value).font(.system(size: 11)).foregroundStyle(.white)
                    Button { remove() } label: { Image(systemName: "xmark").font(.system(size: 8)).foregroundStyle(.white.opacity(0.34)) }
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(Color(white: 0.16)))
            } else {
                Button(action: add) {
                    HStack(spacing: 6) {
                        Image(systemName: systemImage).font(.system(size: 10)).foregroundStyle(.white.opacity(0.34))
                        Text(label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.56))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.06)))
                    .overlay(Capsule().stroke(.white.opacity(0.09), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 最近 速记/日记/任务 (HTML .recents) — seed data; real recents need backend.
    // TODO(align-capture): replace recentSeed with a backend recents query.
    private let recentSeed: [(kind: String, text: String, time: String)] = [
        ("速记", "开会记得问 CI 的事", "2m"), ("速记", "刘海配色换 teal", "40m"),
        ("任务", "明早 9 点跑回归测试", "1h"), ("任务", "review notch PR #51", "2h"),
        ("日记", "今天把刘海重做了一版", "3h"),
    ]

    private var recentsSection: some View {
        let label = model.captureKind.label
        let items = recentSeed.filter { $0.kind == label }
        return VStack(alignment: .leading, spacing: 0) {
            Button { model.captureShowRecent.toggle() } label: {
                Text("最近\(label) \(model.captureShowRecent ? "▴" : "▾")")
                    .font(.system(size: 10, weight: .bold)).tracking(0.4).foregroundStyle(.white.opacity(0.34))
            }
            .buttonStyle(.plain)
            if model.captureShowRecent {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if items.isEmpty {
                            Text("暂无").font(.system(size: 11)).foregroundStyle(.white.opacity(0.34))
                                .frame(width: 160, height: 52, alignment: .topLeading)
                        } else {
                            ForEach(items.indices, id: \.self) { i in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(items[i].kind).font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.03))
                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                        .background(RoundedRectangle(cornerRadius: 5).fill(accent))
                                    Text(items[i].text).font(.system(size: 11)).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                                    Text(items[i].time).font(.system(size: 9)).foregroundStyle(.white.opacity(0.34))
                                }
                                .frame(width: 160, alignment: .topLeading)
                                .padding(.horizontal, 11).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 11).fill(.white.opacity(0.04)))
                                .overlay(RoundedRectangle(cornerRadius: 11).stroke(.white.opacity(0.09), lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: Resize handle (width only — height is now auto per-view)
    //
    // TODO(align): pending [needs-human] — per-view auto-height (HTML viewHeight())
    // supersedes the persisted drag-resize *height* from decision 09eb9245. Width
    // stays user-adjustable; height follows the active module.

    private var resizeHandle: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.25))
            .padding(7)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        model.resize(
                            width: model.expandedWidth + value.translation.width * 2,
                            height: model.expandedHeight)  // height auto; keep as-is
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
        case .focus: "我现在在做什么…"
        case .ask: "问问 Helm 大脑…"
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

/// The HTML `.shine` — text with a bright band sweeping across (a running agent
/// "thinking" shimmer). Falls back to a static dim label off-screen.
private struct ShineText: View {
    let text: String
    var accent: Color
    var size: CGFloat = 11
    @State private var animate = false

    init(_ text: String, accent: Color, size: CGFloat = 11) {
        self.text = text
        self.accent = accent
        self.size = size
    }

    private var font: Font { .system(size: size, weight: .medium) }

    var body: some View {
        Text(text).font(font).foregroundStyle(.white.opacity(0.35)).lineLimit(1)
            .overlay {
                GeometryReader { geo in
                    LinearGradient(colors: [.clear, .white, accent, .clear],
                                   startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width)
                        .offset(x: animate ? geo.size.width : -geo.size.width)
                        .mask(Text(text).font(font).lineLimit(1))
                        .animation(.linear(duration: 1.6).repeatForever(autoreverses: false), value: animate)
                }
            }
            .fixedSize()
            .onAppear { animate = true }
    }
}

/// The HTML `.cstar` — a slowly spinning ✻ that marks a running agent.
private struct SpinningStar: View {
    var color: Color
    @State private var spin = false
    var body: some View {
        Text("✻").font(.system(size: 12)).foregroundStyle(color)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}

/// `.mwave` — a 44-bar monochrome visualizer (sine base heights, staggered
/// dance). Bars freeze when playback is paused.
private struct Waveform: View {
    var playing: Bool
    var color: Color
    @State private var animate = false
    private let n = 44

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<n, id: \.self) { i in
                    let frac = 0.20 + 0.46 * abs(sin(Double(i) * 0.9 + 1))
                    Capsule().fill(color).opacity(0.5)
                        .frame(maxWidth: .infinity)
                        .frame(height: max(2, geo.size.height * frac))
                        .scaleEffect(CGSize(width: 1, height: animate ? 1 : 0.32), anchor: .bottom)
                        .animation(
                            playing
                                ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                                    .delay(Double((i * 37) % 13) * 0.11)
                                : .default,
                            value: animate)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .mask(LinearGradient(
                stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.07),
                        .init(color: .black, location: 0.93), .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing))
        }
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
