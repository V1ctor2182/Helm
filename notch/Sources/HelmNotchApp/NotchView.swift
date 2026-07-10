import AppKit
import HelmNotchCore
import SwiftUI
import UniformTypeIdentifiers

/// The notch surface. Collapsed: a bar hugging the physical notch (media left ·
/// camera gap · status glyph right). Hover → expand into the dock panel: a top
/// bar, one switchable module (dashboard / 速记 / calendar / dev / clipboard, plus
/// the media zoom), and a bottom dock. Height auto-fits each module; accent
/// rotates daily. Ported 1:1 from helm-notch-pro.html.
struct NotchView: View {
    @Bindable var model: NotchModel
    @FocusState private var captureFocused: Bool
    @State private var dragOver = false
    // 日记续写富文本编辑器的选区格式化器(B/I/H)
    @State private var journalFormatter = JournalFormatter()
    // NOMI 总览速记胶囊(quickcap)
    @State private var quickText = ""
    @FocusState private var quickCapFocused: Bool
    // NOMI 日历加事件
    @State private var calAddText = ""
    @FocusState private var calAddFocused: Bool
    // 专注·换任务行内编辑
    @State private var focusEditing = false
    @State private var focusTaskDraft = ""
    @FocusState private var focusTaskFocused: Bool

    private var accent: Color { Color(model.accent) }

    private let collapsedBarHeight = CGFloat(NomiTheme.foldedHeight)  // 34,NOMI .hw
    // ~100px per side around the camera gap (HTML #bar: (360−160)/2), so the
    // media title reads as "Counting My Bless…" instead of truncating hard.
    private var collapsedWidth: CGFloat { model.collapsedWidth }

    var body: some View {
        // Banner states override collapsed/expanded. Reminder (560×152) takes
        // precedence over a permission request (620×208) — matching HTML render().
        let waiting = model.bannerSuppressed ? nil : model.localSessions.first(where: { $0.needsAttention })
        let reminder = model.reminder
        // 拖文件悬停 → 壳长出 drop 承接面(设计稿 dropmode,2026-07-07 用户拍板),
        // 即时交互压过横幅/提醒;拖走即回原态(不动 model.expanded)。
        let shellW: CGFloat = dragOver ? model.expandedWidth
            : (reminder != nil ? 560 : (waiting != nil ? model.bannerSize.width : (model.expanded ? model.expandedShellWidth : collapsedWidth)))
        let shellH: CGFloat = dragOver ? dropModeHeight
            : (reminder != nil ? 152 : (waiting != nil ? model.bannerSize.height : (model.expanded ? model.autoExpandedHeight : collapsedBarHeight)))
        shell(width: shellW, height: shellH, banner: waiting, reminder: reminder)
            // 深/浅跟 nomiDark 走:否则系统浅色时,TextField 占位符等系统
            // 自配色按浅色方案渲染,深面板上直接看不见(2026-07-07 用户截图)。
            .preferredColorScheme(model.nomiDark ? .dark : .light)
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
            if dragOver {
                VStack(spacing: 0) {
                    topBar
                    dropTargetSurface
                }
                .transition(.opacity)
            } else if let reminder {
                remindBanner(reminder)
            } else if let banner {
                // 选择题解析成功走可作答横幅;其余(含解析失败兜底)走允许/拒绝。
                if banner.question != nil {
                    QuestionBannerView(session: banner, accent: accent, model: model)
                        .frame(width: model.bannerSize.width, height: model.bannerSize.height, alignment: .topLeading)
                } else {
                    permissionBanner(banner)
                }
            } else if model.expanded {
                // Only the expanded panel exists while open — the collapsed bar's
                // repeatForever animations aren't left running invisibly (jank).
                expandedPanel
                    .frame(width: model.expandedShellWidth, height: model.autoExpandedHeight, alignment: .top)
                    .transition(.opacity)
            } else {
                collapsedBar
                    .transition(.opacity)
            }
        }
        .frame(width: width, height: height, alignment: .top)
        // NOMI 单体生长:折叠=纯黑条;展开=面板底色(深 #0f0f11/浅 #fff)。
        // 玻璃材质暂退役(B11 设置页收尾时再定去留)。
        .background((model.expanded || banner != nil || reminder != nil || dragOver)
            ? Color(model.nomi.shellBG)
            : (model.nomiDark ? .black : Color(model.nomi.shellBG)))  // 浅色折叠态=白(2026-07-08 用户)
        .clipShape(NotchShape(bottomRadius: (model.expanded || banner != nil || reminder != nil || dragOver)
            ? CGFloat(NomiTheme.openRadius) : CGFloat(NomiTheme.foldedRadius)))
        .animation(Nomi.ease(0.46), value: dragOver)  // drop 态生长/收回同 hover 手感
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
        // SwiftUI 的 hover tracking 会随子树重建(如媒体歌词 TimelineView 每 0.3s
        // tick)反复失效——鼠标贴顶边时只发 exited 不补 entered → 面板收起,收起后
        // 又 entered → 展开,循环"抽风"(2026-07-04 用户)。false 一律用全局鼠标位置
        // 对活动区做权威复核,误报直接吞掉;真离开照常收起。
        .onHover { inside in
            if !inside && Self.mouseInsideActiveRegion(model: model) { return }
            model.hover(inside)
        }
        // iOS-style shell grow (content has its own, delayed, animations above).
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.54), value: model.expanded)
        // Animate the height re-flow when the active view changes (HTML notch
        // width/height transition = .46s cubic-bezier(.32,.72,0,1)).
        .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.46), value: model.autoExpandedHeight)
        .frame(maxWidth: .infinity, alignment: .top)  // center the shell in the canvas
    }

    /// AppKit 权威判定:全局鼠标是否仍在面板活动区(屏幕顶部中央 W×H,含容差)。
    /// 用来吞掉 SwiftUI onHover 因子树重建(媒体 TimelineView tick)发出的虚假 exited。
    private static func mouseInsideActiveRegion(model: NotchModel) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let waiting = model.bannerSuppressed ? nil : model.localSessions.first(where: { $0.needsAttention })
        let w: CGFloat = waiting != nil
            ? model.bannerSize.width
            : (model.reminder != nil ? 560 : (model.expanded ? model.expandedWidth : model.collapsedWidth))
        let h: CGFloat = waiting != nil
            ? model.bannerSize.height
            : (model.reminder != nil ? 152 : (model.expanded ? CGFloat(model.autoExpandedHeight) : 32))
        let f = screen.frame
        let m = NSEvent.mouseLocation
        let pad: CGFloat = 4
        return m.x >= f.midX - w / 2 - pad && m.x <= f.midX + w / 2 + pad
            && m.y >= f.maxY - h - pad && m.y <= f.maxY
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

    /// Now-playing to render — real when available, else HTML's demo song so the
    /// media surfaces match the design out of the box (like the agent demo).
    private var shownNowPlaying: NowPlaying {
        model.nowPlaying ?? NowPlaying(
            title: "Counting My Blessings", artist: "Seph Schlueter",
            isPlaying: true, elapsed: 42, duration: 91)
    }
    /// Fraction 0…1 for the media progress bar (live for real playback, static
    /// elapsed/duration for the demo song).
    private func mediaFraction(_ np: NowPlaying, at now: Date) -> Double {
        let total = np.duration ?? 0
        guard total > 0 else { return 0.42 }
        let pos = model.nowPlaying != nil ? model.livePosition(at: now) : (np.elapsed ?? 0)
        return min(1, pos / total)
    }

    /// dropmode 承接面(设计稿 .droptarget):渐变圆+下落箭头,虚线框亮橙。
    private let dropModeHeight: CGFloat = 196
    private var dropTargetSurface: some View {
        let pal = model.nomi
        return VStack(spacing: 10) {
            Circle().fill(Nomi.gradient)
                .frame(width: 40, height: 40)
                .overlay(Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white))
            VStack(spacing: 3) {
                Text("松手 — 暂存到 Shelf").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(pal.ink))
                Text("上传到记录,拖走前都在暂存页").font(.system(size: 10.5)).foregroundStyle(Color(pal.ink3))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NomiTheme.g1).opacity(0.07)))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(NomiTheme.g1), style: StrokeStyle(lineWidth: 2, dash: [6, 5])))
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 16, trailing: 16))
    }

    // MARK: Collapsed — one continuous bar (left content · camera gap · right glyph)

    private var collapsedBar: some View {
        HStack(spacing: 0) {
            collapsedLeft
                .padding(.leading, 13)
                .padding(.trailing, 11)
            // 摄像头区:常驻黑凹槽条(深色下与条同色隐形;浅色下即设计稿 hw 黑条)。
            UnevenRoundedRectangle(
                bottomLeadingRadius: CGFloat(NomiTheme.foldedRadius),
                bottomTrailingRadius: CGFloat(NomiTheme.foldedRadius), style: .continuous)
                .fill(.black)
                .frame(width: CGFloat(model.notchWidth))
                .overlay(alignment: .top) {
                    Circle().fill(Color(white: 0.05))
                        .overlay(Circle().stroke(Color(white: 0.17), lineWidth: 1))
                        .frame(width: 7, height: 7).padding(.top, 8)
                }
            collapsedRight
                .padding(.leading, 11)
                .padding(.trailing, 13)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(height: collapsedBarHeight)
        // 实测内容宽度回填 model(窗口和黑壳都用它)——定宽估算会戳壳/留黑边
        .background(GeometryReader { g in
            Color.clear
                .onAppear { model.collapsedMeasuredWidth = ceil(g.size.width) }
                .onChange(of: g.size.width) { _, w in model.collapsedMeasuredWidth = ceil(w) }
        })
        .frame(width: collapsedWidth, height: collapsedBarHeight)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    /// NOMI 折叠左组:logo(常驻)+ 迷你封面 + 渐变波形(播放时)。
    /// 专注态沿用计时显示(设计稿未覆盖,行为保留)。
    @ViewBuilder private var collapsedLeft: some View {
        if model.focusOn {
            HStack(spacing: 6) {
                Image(systemName: "timer").font(.system(size: 11)).foregroundStyle(Color(NomiTheme.g1))
                Text(model.focusWhat).font(.system(size: 10, weight: .medium)).foregroundStyle(Color(model.nomi.ink)).lineLimit(1)
            }
        } else {
            HStack(spacing: 9) {
                HelmLogoView(color: Color(model.nomi.logo), size: 19)
                if let np = model.nowPlaying {
                    MiniCover(artwork: nsArtwork(np))
                    if np.isPlaying {
                        WaveBars()
                    } else {
                        Image(systemName: "pause.fill").font(.system(size: 9)).foregroundStyle(Color(model.nomi.ink3))
                    }
                }
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
        // Collapsed bar reflects REAL sessions only (no demo fallback).
        let waiting = model.localSessions.filter(\.needsAttention).count
        let running = model.localSessions.filter { $0.phase == .running }.count
        if model.focusOn {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let s = model.focusRemaining(at: context.date)
                HStack(spacing: 5) {
                    Circle().fill(Color(NomiTheme.g1)).frame(width: 6, height: 6)
                    Text(String(format: "%02d:%02d", s / 60, s % 60))
                        .font(.system(size: 12, weight: .bold)).monospacedDigit()
                        .foregroundStyle(Color(NomiTheme.g1))
                }
            }
        } else if waiting > 0 {
            // 待批准:橙点 + 数(backlog Q1 口径;真等待时横幅本来就会弹)。
            HStack(spacing: 5) {
                Circle().fill(Nomi.warn).frame(width: 6, height: 6)
                Text("\(waiting) 待批").font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(NomiTheme.warn))
            }
        } else if running > 0 {
            // NOMI .stat:绿点 + "N live" mono。
            HStack(spacing: 5) {
                Circle().fill(Nomi.ok).frame(width: 6, height: 6)
                Text("\(running) live").font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(model.nomi.ink2))
            }
        } else if let ev = model.events.first {
            // HTML cev: next event "10:00 站会" (accent time + name).
            HStack(spacing: 5) {
                Text(ev.when).font(.system(size: 10, weight: .bold)).foregroundStyle(Color(NomiTheme.g1)).monospacedDigit()
                Text(ev.summary).font(.system(size: 10)).foregroundStyle(Color(model.nomi.ink2))
                    .lineLimit(1).frame(maxWidth: 80, alignment: .leading)
            }
        } else {
            Circle().fill(Color(model.nomi.hair)).frame(width: 8, height: 8)
        }
    }

    // MARK: Expanded — dock + module router (ported from helm-notch-pro.html #panel)

    /// `#panel`: top bar (logo · gear) → switchable module view → dock.
    private var expandedPanel: some View {
        VStack(spacing: 0) {
            topBar
            moduleBody
                .id(model.module)
                .transition(moduleTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.36), value: model.module)
            // NOMI 稿:mtabs 常驻,媒体页也显示 dock(预算 330 已含)。
            dockBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Extra breathing room from the rounded panel edges (device feedback).
        .padding(.horizontal, 8)
    }

    /// Module transition: media zooms (HTML zoomTo — dash↔media), everything else
    /// slides (HTML slideTo). SwiftUI keeps a removed view's transition, so keying
    /// the zoom on `module == .media` gives media a zoom-in on enter + zoom-out on
    /// leave; the dashboard counterpart slides.
    // TODO(align-zoom): dash side slides while media zooms — tune on device if the
    // mix reads off; HTML zooms both sides symmetrically.
    private var moduleTransition: AnyTransition {
        if model.module == .media {
            // HTML zoomTo: scale-in .955→1 on enter, scale-out to .97 on leave.
            return .asymmetric(
                insertion: .scale(scale: 0.955).combined(with: .opacity),
                removal: .scale(scale: 0.97).combined(with: .opacity))
        }
        // HTML slideTo: a subtle ±46px translateX + fade — NOT a full-width move.
        let f = model.moduleSwitchForward
        return .asymmetric(
            insertion: .notchSlide(dx: f ? 46 : -46, dy: 0),
            removal: .notchSlide(dx: f ? -46 : 46, dy: 0))
    }

    /// NOMI toprow:左 tl(娃娃脸 logo+Helm)· 中 hw 黑条常驻摄像头凹槽 ·
    /// 右 tr(锁态 X+齿轮)。天气位暂空——无真实数据源,不放假灯(backlog Q3)。
    private var topBar: some View {
        let p = model.nomi
        // 凹槽只需盖住物理摄像头+呼吸(240 下限);之前取设计值 310 会把
        // 两翼挤到 65pt,浅色下 Helm 字撞进黑条隐形(2026-07-08 用户截图)。
        let stripW = max(240, CGFloat(model.notchWidth) + 20)
        return ZStack {
            UnevenRoundedRectangle(
                bottomLeadingRadius: CGFloat(NomiTheme.foldedRadius),
                bottomTrailingRadius: CGFloat(NomiTheme.foldedRadius), style: .continuous)
                .fill(.black)
                .frame(width: stripW, height: CGFloat(NomiTheme.foldedHeight))
                .overlay {
                    Circle().fill(Color(white: 0.09))
                        .overlay(Circle().stroke(Color(white: 0.04), lineWidth: 2.5))
                        .frame(width: 8, height: 8)
                }
            HStack(spacing: 5) {
                HelmLogoView(color: Color(p.logo), size: 17)
                Text("Helm").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(p.ink))
                    .lineLimit(1).fixedSize()
                Spacer()
                if model.locked {
                    Button { model.collapse() } label: {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Color(p.ink3))
                }
                Button { model.openSettings?() } label: {
                    Image(systemName: "gearshape").font(.system(size: 13))
                        .foregroundStyle(Color(p.ink3))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: CGFloat(NomiTheme.foldedHeight))
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
        HStack(spacing: 8) {
            ForEach(NotchModule.dock) { m in dockButton(m) }
        }
        .padding(.top, 6).padding(.bottom, 7)
        .frame(maxWidth: .infinity)
        // Keep the active-state change snappy (HTML .dk transition .12s) instead of
        // letting it inherit the slow panel height/slide animation on module switch.
        .animation(.easeOut(duration: 0.12), value: model.module)
    }

    private func dockButton(_ m: NotchModule) -> some View {
        let on = model.module == m
        let badge = (m == .agents && model.localAttentionCount > 0)
        let p = model.nomi
        return Button { model.selectModule(m) } label: {
            Image(systemName: m.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(on ? Color(p.ink) : Color(p.ink2))
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(p.pill)))
                // NOMI 激活态:渐变描边环(HTML .mtab.on border-box 渐变)。
                .overlay(Circle().stroke(Nomi.gradient, lineWidth: on ? 2 : 0))
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
        case .agents:
            agentsModule
        case .files:
            filesModule
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

    // NOMI 总览 bento(HTML .bento):大媒体卡跨两行 + 日历卡 + 智能体卡 + 速记胶囊。
    private var dashboardModule: some View {
        let p = model.nomi
        return GeometryReader { geo in
            let gap: CGFloat = 10
            let rightW = (geo.size.width - gap) / 2.35  // 1.35fr : 1fr
            VStack(spacing: gap) {
                HStack(alignment: .top, spacing: gap) {
                    bentoMedia
                        .frame(maxWidth: .infinity)
                    VStack(spacing: gap) {
                        bentoCal(p)
                        bentoAgent(p)
                    }
                    .frame(width: rightW)
                }
                quickCap(p)
            }
        }
        .padding(.horizontal, 18).padding(.top, 8)
    }

    /// .b-media:渐变底大卡,封面/音符居中,meta 压底,eq 呼吸柱右下;点→媒体。
    private var bentoMedia: some View {
        let np = shownNowPlaying
        return ZStack(alignment: .bottomLeading) {
            if let art = model.nowPlaying.flatMap(nsArtwork) {
                GeometryReader { g in
                    Image(nsImage: art).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: g.size.width, height: g.size.height).clipped()
                }
            } else {
                LinearGradient(colors: [Color(red: 0.149, green: 0.125, blue: 0.173),
                                        Color(red: 0.098, green: 0.102, blue: 0.125)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 30)).foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(np.title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text(np.subtitle).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }
                Spacer(minLength: 4)
                // 卡上直接控制(2026-07-07 用户):前/播暂/后;点卡片其余区域仍进媒体页
                HStack(spacing: 5) {
                    bentoMediaButton("backward.fill", size: 22, icon: 8) { model.previousTrack() }
                    bentoMediaButton(np.isPlaying ? "pause.fill" : "play.fill", size: 26, icon: 10) { model.playPause() }
                    bentoMediaButton("forward.fill", size: 22, icon: 8) { model.nextTrack() }
                }
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 10, trailing: 12))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, Color(red: 0.04, green: 0.04, blue: 0.047).opacity(0.82)],
                                       startPoint: .top, endPoint: .bottom))
        }
        .frame(minHeight: 128)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if np.isPlaying { WaveBars(heights: [5, 10, 7]).padding(.trailing, 12).padding(.top, 12) }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectModule(.media) }
    }

    /// 媒体大卡上的迷你控制钮(半透明白底,吃掉自己的点击不触发卡片 zoom)。
    private func bentoMediaButton(_ symbol: String, size: CGFloat, icon: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: icon, weight: .semibold)).foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(.white.opacity(0.16)))
        }.buttonStyle(.plain)
    }

    /// .bcard 日历:spark+「日历 · 下一项」/事件/副行;无日程诚实显示。点→日历。
    private func bentoCal(_ p: NomiPalette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                SparkDot()
                Text("日历 · 下一项").font(.system(size: 10)).foregroundStyle(Color(p.ink3)).tracking(0.3)
            }
            if let ev = model.events.first {
                Text("\(ev.when) \(ev.summary)")
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color(p.ink))
                    .lineLimit(1).padding(.top, 5)
                if let next = model.events.dropFirst().first {
                    Text("之后 \(next.when) \(next.summary)")
                        .font(.system(size: 10.5)).foregroundStyle(Color(p.ink3)).lineLimit(1).padding(.top, 2)
                }
            } else {
                Text("今日无日程").font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color(p.ink2)).padding(.top, 5)
            }
        }
        .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .wcard(p, dark: model.nomiDark)
        .contentShape(Rectangle())
        .onTapGesture { model.selectModule(.calendar) }
    }

    /// .bcard 智能体:okdot+「智能体」/会话名/状态行。点→智能体。
    private func bentoAgent(_ p: NomiPalette) -> some View {
        let s = displaySessions.first
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(s?.needsAttention == true ? Nomi.warn : Nomi.ok).frame(width: 8, height: 8)
                Text("智能体").font(.system(size: 10)).foregroundStyle(Color(p.ink3)).tracking(0.3)
            }
            if let s {
                Text("claude · \(s.folderName)")
                    .font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color(p.ink))
                    .lineLimit(1).padding(.top, 5)
                Text(s.activity ?? (s.phase == .idle ? "空闲 — 可回复" : s.phase == .running ? "思考中…" : "—"))
                    .font(.system(size: 10.5)).foregroundStyle(Color(p.ink3)).lineLimit(1).padding(.top, 2)
            } else {
                Text("暂无会话").font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color(p.ink2)).padding(.top, 5)
            }
        }
        .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .wcard(p, dark: model.nomiDark)
        .contentShape(Rectangle())
        .onTapGesture { model.selectModule(.agents) }
    }

    /// .quickcap:胶囊速记条(⏎/发送 → 后端 note)。
    private func quickCap(_ p: NomiPalette) -> some View {
        HStack(spacing: 8) {
            TextField("", text: $quickText, prompt: Text("速记一笔 — ⏎ 发送,链接自动解析…").foregroundStyle(Color(p.ink3)))
                .textFieldStyle(.plain)
                .font(.system(size: 12.5)).foregroundStyle(Color(p.ink))
                .focused($quickCapFocused)
                .onSubmit(sendQuickCap)
            Button("发送", action: sendQuickCap)
                .buttonStyle(GradientButtonStyle())
        }
        .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 5))
        .background(Capsule().fill(Color(p.pill)))
        .onChange(of: quickCapFocused) { _, focused in
            if focused { model.beginCapture() } else { model.endInteraction() }
        }
    }

    private func sendQuickCap() {
        let text = quickText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        quickText = ""
        Task { await model.quickNote(text) }
    }

    // MARK: Calendar module — NOMI 周条+今日事件+加事件(月视图随稿退役)

    /// NOMI cal:weekbar 7 天(今天=渐变胶囊)· 事件行(mono 时间+渐变竖条)·
    /// addev 胶囊(无建事件 API → 交给 agent 任务解析时间,真通道非假灯)。
    private var calendarModule: some View {
        let pal = model.nomi
        return VStack(alignment: .leading, spacing: 0) {
            calWeekBar(pal)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if model.events.isEmpty {
                        Text("今日无日程")
                            .font(.system(size: 12)).foregroundStyle(Color(pal.ink3))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 26)
                    } else {
                        ForEach(Array(model.events.enumerated()), id: \.element.id) { i, ev in
                            calEventRow(ev, pal: pal)
                                .overlay(alignment: .top) {
                                    if i > 0 { Rectangle().fill(Color(pal.hair)).frame(height: 1) }
                                }
                        }
                    }
                }
            }
            calAddEvent(pal)
        }
        .padding(.top, 12).padding(.horizontal, 18).padding(.bottom, 4)
    }

    private func calWeekBar(_ pal: NomiPalette) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        // 周一开头的本周 7 天
        let weekday = (cal.component(.weekday, from: today) + 5) % 7  // Mon=0
        let monday = cal.date(byAdding: .day, value: -weekday, to: today)!
        let labels = ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: monday)!
                let isToday = cal.isDate(day, inSameDayAs: today)
                VStack(spacing: 2) {
                    Text("周\(labels[i])").font(.system(size: 9))
                        .foregroundStyle(isToday ? .white.opacity(0.8) : Color(pal.ink3))
                    Text("\(cal.component(.day, from: day))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(isToday ? .white : Color(pal.ink))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 7).padding(.bottom, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isToday ? AnyShapeStyle(Nomi.gradient) : AnyShapeStyle(.clear)))
            }
        }
        .padding(.bottom, 11)
    }

    private func calEventRow(_ ev: CalEvent, pal: NomiPalette) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(ev.when).font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color(pal.ink3))
                .frame(width: 40, alignment: .leading).padding(.top, 2)
            RoundedRectangle(cornerRadius: 2).fill(Nomi.gradientV).frame(width: 3)
            Text(ev.summary).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Color(pal.ink))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8).padding(.horizontal, 2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func calAddEvent(_ pal: NomiPalette) -> some View {
        HStack(spacing: 8) {
            TextField("", text: $calAddText, prompt: Text("加事件:明天 3pm 和 Sam 过设计…(AI 解析时间)").foregroundStyle(Color(pal.ink3)))
                .textFieldStyle(.plain)
                .font(.system(size: 12)).foregroundStyle(Color(pal.ink))
                .focused($calAddFocused)
                .onSubmit(sendCalAdd)
            Button("添加", action: sendCalAdd)
                .buttonStyle(InkButtonStyle(palette: pal))
        }
        .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 5))
        .background(Capsule().fill(Color(pal.pill)))
        .padding(.top, 8)
        .onChange(of: calAddFocused) { _, focused in
            if focused { model.beginCapture() } else { model.endInteraction() }
        }
    }

    private func sendCalAdd() {
        let text = calAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        calAddText = ""
        Task { await model.addEventViaAgent(text) }
    }

    // MARK: 智能体 module(NOMI:会话/端口/PR 三子页;B9 换上下滑 snap+sdots)

    /// `.devwrap` — the current sub-page on the left, a minimal vertical pager
    /// rail on the right. The rail dot for the active section elongates in accent.
    private var agentsModule: some View {
        HStack(spacing: 6) {
            agentStage
                .id(model.agentPage)
                .transition(agentPageTransition)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
                .animation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.36), value: model.agentPage)
            agentRail
        }
        .padding(.top, 14).padding(.horizontal, 16).padding(.bottom, 6)
    }

    /// Vertical slide (HTML slideDev): down → new enters from the bottom.
    private var agentPageTransition: AnyTransition {
        // HTML slideDev: a subtle ±34px translateY + fade.
        let f = model.agentPageForward
        return .asymmetric(
            insertion: .notchSlide(dx: 0, dy: f ? 34 : -34),
            removal: .notchSlide(dx: 0, dy: f ? -34 : 34))
    }

    @ViewBuilder private var agentStage: some View {
        switch model.agentPage {
        case .sessions: VStack(alignment: .leading, spacing: 0) { agentCell }
        case .ports: portsPage
        case .prs: prsPage
        }
    }

    /// NOMI .sdots:右缘子页圆点,激活=渐变 14px 长条。
    private var agentRail: some View {
        VStack(spacing: 5) {
            ForEach(AgentPage.allCases) { s in
                let on = model.agentPage == s
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(on ? AnyShapeStyle(Nomi.gradientV) : AnyShapeStyle(Color(model.nomi.hair)))
                    .frame(width: 5, height: on ? 14 : 5)
                    .contentShape(Rectangle().inset(by: -4))
                    .onTapGesture { model.selectAgentPage(s) }
                    .animation(.easeOut(duration: 0.2), value: model.agentPage)
            }
        }
        .frame(width: 14)
        .frame(maxHeight: .infinity)
    }

    /// 端口子页:真 lsof 数据(portsProvider 注入;进入页面刷新)。
    private var portsPage: some View {
        let pal = model.nomi
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("本地端口").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(pal.ink2))
                Text("LISTENING · lsof").font(.system(size: 10)).foregroundStyle(Color(pal.ink3)).tracking(0.4)
                Spacer()
                if model.portsRefreshing {
                    Text("探测中…").font(.system(size: 9.5)).foregroundStyle(Color(pal.ink3))
                }
            }
            .padding(.horizontal, 2).padding(.bottom, 2)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 7) {
                    if model.localPorts.isEmpty && !model.portsRefreshing {
                        Text(model.portsProvider == nil ? "端口探测未接线" : "没有监听中的 TCP 端口")
                            .font(.system(size: 11)).foregroundStyle(Color(pal.ink3))
                            .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                    }
                    ForEach(model.localPorts) { info in
                        HStack(spacing: 10) {
                            Circle().fill(Nomi.ok).frame(width: 7, height: 7)
                            Text(verbatim: ":\(info.port)")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(pal.ink)).frame(minWidth: 44, alignment: .leading)
                            Text(info.name).font(.system(size: 11.5)).foregroundStyle(Color(pal.ink2))
                                .lineLimit(1).truncationMode(.tail)
                            Spacer(minLength: 6)
                            Button("打开") {
                                if let url = URL(string: "http://localhost:\(info.port)") { NSWorkspace.shared.open(url) }
                            }
                            .buttonStyle(PillButtonStyle(palette: pal))
                        }
                        .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 9))
                        .wcard(pal, dark: model.nomiDark)
                    }
                }
            }
        }
        .task { await model.refreshLocalPorts() }
    }

    /// PR 子页:NOMI prrow 卡。数据源待定(后端契约不动)→ seed 演示 + 明示「示例」,
    /// 接真源记 backlog(TODO(align-pr):gh CLI / 后端出接口)。
    private var prsPage: some View {
        let pal = model.nomi
        let rows: [(src: String, title: String, chip: String, warn: Bool, sub: String)] = [
            ("GH", "#52 design: 主工作台外壳+Today", "checks ✓", false, "可合并 · 2 approvals · main ← feat/shell"),
            ("GH", "#54 loop docs 复审", "CI 跑着", true, "macOS job 还剩 ~2 分钟"),
            ("GT", "feat/cockpit-fanbox", "3 commits 未推", true, "最近:notch banner 单体化 · 2 分钟前"),
        ]
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("PR · COMMIT 监听").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(pal.ink2))
                Text("示例数据 · 接入待定").font(.system(size: 10)).foregroundStyle(Color(pal.ink3)).tracking(0.4)
                Spacer()
            }
            .padding(.horizontal, 2).padding(.bottom, 2)
            ForEach(rows.indices, id: \.self) { i in
                let r = rows[i]
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(r.src).font(.system(size: 9, weight: .heavy)).foregroundStyle(Color(pal.onInk))
                            .frame(width: 20, height: 20)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(pal.ink)))
                        Text(r.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(pal.ink))
                            .lineLimit(1).truncationMode(.tail)
                        Spacer(minLength: 6)
                        Text(r.chip).font(.system(size: 9.5))
                            .foregroundStyle(Color(RGB(hex: model.nomiDark
                                ? (r.warn ? "ffc58a" : "7fe0a0") : (r.warn ? "c05e00" : "177a36"))))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color(RGB(hex: model.nomiDark
                                ? (r.warn ? "3a2c1e" : "1e3a26") : (r.warn ? "fff4e8" : "e9f8ee")))))
                    }
                    Text(r.sub).font(.system(size: 10.5)).foregroundStyle(Color(pal.ink3)).lineLimit(1)
                }
                .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .wcard(pal, dark: model.nomiDark)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Media module (V.media / .mfull — blurred cover · cover/lyrics · waveform)
    //
    // TODO(align-media-height): HTML `VH.media`=330 — per-view auto-height isn't
    // ported yet; this renders within the current resizable panel height.

    // NOMI 媒体页(.media2):‹总览 返回条;左列 196(封面 88+标题+渐变进度+控制钮);
    // 右列歌词 roll(上下渐隐 mask,当前句加大高亮)。背景=面板底色,不再糊封面。
    private var mediaModule: some View {
        let np = model.nowPlaying
        let pal = model.nomi
        let title = np?.title ?? "未在播放"
        let artist = np.map { $0.artist.isEmpty ? "—" : $0.artist } ?? "打开任意播放器开始"
        let noLyrics = model.lyrics == Lyrics.none
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button("‹ 总览") { model.selectModule(.dashboard) }
                    .buttonStyle(PillButtonStyle(palette: pal))
                Text("媒体").font(.system(size: 10)).foregroundStyle(Color(pal.ink3))
                Spacer()
                Button { model.cycleMediaSource() } label: {
                    HStack(spacing: 6) {
                        SparkDot(size: 7)
                        Text(model.mediaSource.label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color(pal.ink2))
                    }
                }
                .buttonStyle(PillButtonStyle(palette: pal))
            }
            .padding(.bottom, 9)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: noLyrics ? .center : .leading, spacing: 0) {
                    coverArt(np, size: 76, radius: 16)
                        .shadow(color: .black.opacity(model.nomiDark ? 0 : 0.18), radius: 8, y: 4)
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(Color(pal.ink))
                        .lineLimit(1).padding(.top, 8)
                    Text(artist).font(.system(size: 11)).foregroundStyle(Color(pal.ink3)).lineLimit(1).padding(.top, 2)
                    mediaProgress(np).padding(.top, 8)
                    HStack(spacing: 12) {
                        mediaButton("backward.fill", size: 36, pal: pal) { model.previousTrack() }
                        Button { model.playPause() } label: {
                            Image(systemName: (np?.isPlaying ?? true) ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color(pal.onInk))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Color(pal.ink)))
                        }.buttonStyle(.plain)
                        mediaButton("forward.fill", size: 36, pal: pal) { model.nextTrack() }
                    }
                    .padding(.top, 9)
                }
                .frame(maxWidth: noLyrics ? .infinity : 196)
                if !noLyrics {
                    // id 绑曲目:换曲把旧词整棵拆掉,不留跨曲残影;clipped 防越界
                    lyricsColumn
                        .id(model.nowPlaying.map { "\($0.title)|\($0.artist)" } ?? "none")
                        .frame(maxHeight: 176)  // .mlyr 限高:不许把 dock 顶出面板
                        .clipped()
                }
            }
            .frame(maxHeight: .infinity, alignment: noLyrics ? .center : .top)
        }
        .padding(EdgeInsets(top: 10, leading: 18, bottom: 6, trailing: 18))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mediaButton(_ symbol: String, size: CGFloat, pal: NomiPalette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(pal.ink))
                .frame(width: size, height: size)
                .background(Circle().fill(Color(pal.pill)))
        }.buttonStyle(.plain)
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

    /// `.mprog`:6px 渐变进度条(展示;MediaController 无 seek API — 不做假点击,TODO(align-seek))。
    @ViewBuilder private func mediaProgress(_ np: NowPlaying?) -> some View {
        let pal = model.nomi
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let total = np?.duration ?? 0
            let pos = model.livePosition(at: context.date)
            let frac = total > 0 ? min(1, pos / total) : 0
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(pal.pill))
                        Capsule().fill(Nomi.gradientH).frame(width: max(3, geo.size.width * frac))
                    }
                }
                .frame(height: 6)
                HStack {
                    Text(total > 0 ? timeString(pos) : "-:--"); Spacer(); Text(total > 0 ? timeString(total) : "-:--")
                }
                .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(Color(pal.ink3))
            }
        }
    }

    /// `.lyrics` — 真歌词三态:同步(lrclib LRC,按播放位置点亮+滚动)/
    /// 纯文本(静态列表)/无词(诚实提示)。demo 词已删(2026-07-03)。
    @ViewBuilder private var lyricsColumn: some View {
        switch model.lyrics {
        case .synced(let lines):
            if model.nowPlaying?.hasProgress != true {
                // 播放源不给进度(elapsed/duration 缺失)→ 跟不了唱,
                // 优雅降级:静态可滚全词 + 一行说明(2026-07-03 用户:歌词没动)
                VStack(alignment: .leading, spacing: 6) {
                    Text("该播放源不提供进度 — 歌词不跟唱")
                        .font(.system(size: 9)).foregroundStyle(Color(model.nomi.ink3))
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 9) {
                            ForEach(lines.indices, id: \.self) { i in
                                Text(lines[i].text).font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color(model.nomi.ink2)).lineLimit(2)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 6)
                .mask(lyricsMask)
            } else {
            // Apple Music 手感(2026-07-03 用户给了参照图):当前句大号加粗压场、
            // 钉在窗口第二行,唱过的往上推走;其余句按离当前句的距离渐隐。
            TimelineView(.periodic(from: .now, by: 0.3)) { context in
                let pos = model.livePosition(at: context.date)
                let cur = currentLyricIndex(lines, position: pos)
                let window = 5
                let anchor = max(0, cur - 1) // 当前句保持在第二行位置
                let lo = min(anchor, max(0, lines.count - window))
                let hi = min(lines.count, lo + window)
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(lo..<hi, id: \.self) { i in
                        Text(lines[i].text)
                            .font(.system(size: i == cur ? 16.5 : 14.5, weight: i == cur ? .heavy : .semibold))
                            .foregroundStyle(Color(model.nomi.ink).opacity(
                                i == cur ? 1 : max(0.16, 0.38 - 0.09 * Double(abs(i - cur)))))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 6)
                .animation(.easeOut(duration: 0.3), value: cur)
                .mask(lyricsMask)
            }
            }
        case .plain(let lines):
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i]).font(.system(size: 13))
                            .foregroundStyle(Color(model.nomi.ink2)).lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .mask(lyricsMask)
        case .none:
            VStack(spacing: 6) {
                Text("没有找到歌词").font(.system(size: 12)).foregroundStyle(Color(model.nomi.ink2))
                if model.nowPlaying != nil {
                    Text("lrclib 无此曲目").font(.system(size: 10)).foregroundStyle(Color(model.nomi.ink3))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var lyricsMask: LinearGradient {
        LinearGradient(
            stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.05),
                    .init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
            startPoint: .top, endPoint: .bottom)
    }

    // MARK: 暂存页(NOMI files):dropzone + shelf 文件卡 + 真剪贴板段

    private var filesModule: some View {
        let pal = model.nomi
        return VStack(alignment: .leading, spacing: 0) {
            // dropzone:虚线框,shell 级 onDrop 已收文件 → 这里是视觉靶
            VStack(spacing: 3) {
                Text("拖文件到这里(或刘海)").font(.system(size: 11.5, weight: .semibold)).foregroundStyle(Color(pal.ink2))
                Text("暂存到 Shelf → 上传到记录").font(.system(size: 11)).foregroundStyle(Color(pal.ink3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(dragOver ? Color(NomiTheme.g1) : Color(model.nomiDark ? RGB(hex: "3a3a40") : RGB(hex: "d8d8de")),
                            style: StrokeStyle(lineWidth: 1.6, dash: [5, 4])))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(model.captureFiles) { f in shelfRow(f, pal: pal) }
                    Text("剪贴板").font(.system(size: 10, weight: .bold)).tracking(0.4)
                        .foregroundStyle(Color(pal.ink3))
                        .padding(.top, model.captureFiles.isEmpty ? 4 : 10).padding(.horizontal, 2)
                    if model.clipboardHistory.isEmpty {
                        Text("复制点什么就会出现在这里")
                            .font(.system(size: 11)).foregroundStyle(Color(pal.ink3))
                            .padding(.vertical, 6).padding(.horizontal, 2)
                    } else {
                        ForEach(model.clipboardHistory) { c in clipRow(c, pal: pal) }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.top, 12).padding(.horizontal, 18).padding(.bottom, 4)
    }

    private func shelfRow(_ f: CaptureFile, pal: NomiPalette) -> some View {
        HStack(spacing: 10) {
            Text(f.ext).font(.system(size: 9, weight: .heavy)).foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Nomi.gradient))
            Text(f.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(pal.ink))
                .lineLimit(1)
            Spacer(minLength: 6)
            Button("上传到记录") { Task { await model.uploadShelfFile(f.id) } }
                .buttonStyle(PillButtonStyle(palette: pal))
            Button("移除") { model.removeFile(f.id) }
                .buttonStyle(PillButtonStyle(palette: pal))
        }
        .padding(EdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 9))
        .wcard(pal, dark: model.nomiDark)
    }

    private func clipRow(_ c: ClipItem, pal: NomiPalette) -> some View {
        HStack(spacing: 10) {
            Image(systemName: c.isLink ? "link" : "text.alignleft")
                .font(.system(size: 11)).foregroundStyle(Color(pal.ink2))
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(pal.pill)))
            VStack(alignment: .leading, spacing: 1) {
                Text(c.text).font(.system(size: 11.5, weight: c.isLink ? .semibold : .regular))
                    .foregroundStyle(Color(c.isLink ? pal.ink : pal.ink2)).lineLimit(1).truncationMode(.tail)
                Text(clipAge(c.at)).font(.system(size: 9, design: .monospaced)).foregroundStyle(Color(pal.ink3))
            }
            Spacer(minLength: 6)
            Button("复制") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(c.text, forType: .string)
            }
            .buttonStyle(PillButtonStyle(palette: pal))
            Button("存速记") { Task { await model.saveClipToNote(c) } }
                .buttonStyle(PillButtonStyle(palette: pal))
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 9))
        .wcard(pal, dark: model.nomiDark)
    }

    private func clipAge(_ d: Date) -> String {
        let m = max(0, Int(Date().timeIntervalSince(d) / 60))
        return m == 0 ? "刚刚" : (m < 60 ? "\(m) 分钟前" : "\(m / 60) 小时前")
    }

    private func cellHeader(_ title: String, accentTitle: Bool = false, trailing: String? = nil, trailingColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .bold)).tracking(0.6)
                .foregroundStyle(accentTitle ? Color(NomiTheme.g1) : Color(model.nomi.ink3))
            Spacer()
            if let trailing { Text(trailing).font(.system(size: 9, weight: .semibold)).foregroundStyle(trailingColor ?? Color(model.nomi.ink3)) }
        }
    }

    // MARK: Agent cell ↙ (backend runs for now; local Claude Code lands in m3)

    /// Real sessions when the hook is feeding them; otherwise HTML's demo trio
    /// (notch/app/helm) so the view matches the design out of the box.
    private var displaySessions: [LocalSession] {
        if !model.localSessions.isEmpty { return model.localSessions }
        let now = Date()
        return [
            LocalSession(id: "notch", cwd: "~/notch", phase: .running, activity: "正在思考…", updatedAt: now),
            LocalSession(id: "app", cwd: "~/app", phase: .running, activity: "Bash: swift build", updatedAt: now),
            LocalSession(id: "helm", cwd: "~/helm", phase: .ended, updatedAt: now),
        ]
    }

    @ViewBuilder private var agentCell: some View {
        if let sel = model.selectedLocalSession {
            SessionDetailView(session: sel, accent: accent, model: model)
        } else {
            agentList
        }
    }

    @ViewBuilder private var agentList: some View {
        let pal = model.nomi
        let sessions = displaySessions
        let waiting = sessions.filter(\.needsAttention)
        let clickable = !model.localSessions.isEmpty  // demo 卡不可点开详情
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text("会话").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(pal.ink2))
            Text("本机 Claude Code · 上下滑看端口/PR").font(.system(size: 10))
                .foregroundStyle(Color(pal.ink3)).tracking(0.4)
            Spacer()
            if !waiting.isEmpty {
                Text("\(waiting.count) 待处理").font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(NomiTheme.warn))
            }
        }
        .padding(.horizontal, 2).padding(.bottom, 7)
        if let perm = waiting.first {
            permissionCard(perm).padding(.bottom, 8)
        }
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(Array(sessions.filter { !$0.needsAttention }.prefix(3))) { session in
                    sessionCard(session, pal: pal)
                        .contentShape(Rectangle())
                        .onTapGesture { if clickable { model.selectedLocalSessionID = session.id } }
                }
                if sessions.isEmpty {
                    Text("暂无运行中的 agent — 开一个 Claude Code session 就会出现")
                        .font(.system(size: 11)).foregroundStyle(Color(pal.ink3))
                        .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
                }
            }
        }
        Spacer(minLength: 0)
    }

    /// NOMI .sess 卡:光环状态点 + claude·目录 + 右 mono 状态 + 一行动态。
    private func sessionCard(_ s: LocalSession, pal: NomiPalette) -> some View {
        let (dot, halo): (Color, Color) = switch s.phase {
        case .running: (Nomi.ok, Nomi.ok.opacity(0.18))
        case .waitingPermission, .waitingQuestion: (Color(NomiTheme.g1), Color(NomiTheme.g1).opacity(0.18))
        case .idle, .ended: (Color(pal.ink3), Color(pal.pill))
        }
        let line = s.activity ?? s.lastAssistant ?? s.lastPrompt ?? "—"
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(dot).frame(width: 8, height: 8)
                    .background(Circle().fill(halo).frame(width: 14, height: 14))
                Text("claude · \(s.folderName)").font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color(pal.ink)).lineLimit(1)
                Spacer(minLength: 6)
                Text(sessionShortStatus(s)).font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Color(pal.ink3))
            }
            if s.phase == .running && (s.activity == nil || s.activity == "正在思考…") {
                HStack(spacing: 5) {
                    SpinningStar(color: Color(NomiTheme.g1)).scaleEffect(0.78)
                    ShineText("正在思考…", accent: Color(NomiTheme.g1), size: 11)
                }
            } else {
                Text(line).font(.system(size: 11)).foregroundStyle(Color(pal.ink2))
                    .lineLimit(1).truncationMode(.tail)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 13, bottom: 10, trailing: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .wcard(pal, dark: model.nomiDark)
    }

    private func sessionShortStatus(_ s: LocalSession) -> String {
        switch s.phase {
        case .running: "运行中"
        case .waitingPermission: "待批准"
        case .waitingQuestion: "等你回答"
        case .idle: "空闲 · 可回复"
        case .ended: "已结束"
        }
    }

    /// NOMI .permcard:左橙边卡,spark+目录+请求;Allow=kbtn/Deny=pbtn。
    /// (真 diff 等 hook 带 patch 内容,现为 tool/detail — TODO(align-diff))
    private func permissionCard(_ session: LocalSession) -> some View {
        let pal = model.nomi
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                SparkDot()
                Text("claude · \(session.folderName)").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(pal.ink))
                Text("请求执行").font(.system(size: 11)).foregroundStyle(Color(pal.ink2))
            }
            Text(session.pendingDetail ?? session.pendingTool ?? "(请求权限)")
                .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Color(pal.ink2))
                .lineLimit(2).padding(EdgeInsets(top: 6, leading: 9, bottom: 6, trailing: 9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(pal.pill)))
            HStack(spacing: 6) {
                Button("Allow") { model.resolveLocalPermission(session.id, allow: true) }
                    .buttonStyle(InkButtonStyle(palette: pal))
                Button("Deny") { model.resolveLocalPermission(session.id, allow: false) }
                    .buttonStyle(PillButtonStyle(palette: pal, fontSize: 12))
            }
        }
        .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
        .frame(maxWidth: .infinity, alignment: .leading)
        .wcard(pal, dark: model.nomiDark)
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14)
                .fill(Color(NomiTheme.warn)).frame(width: 3)
        }
    }

    // MARK: Permission banner (HTML bannerHTML — pops on waiting_permission)
    //
    // TODO(align-banner): HTML shows a code diff; the hook only sends tool/detail
    // for now, so the request body shows that instead of a real diff.

    private func permissionBanner(_ s: LocalSession) -> some View {
        let pal = model.nomi
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                SparkDot()
                Text("claude · \(s.folderName)").font(.system(size: 11.5, weight: .bold)).foregroundStyle(Color(pal.ink))
                Text(s.pendingTool == "AskUserQuestion" ? "选择题 — 允许后在终端作答" : "请求执行")
                    .font(.system(size: 11.5)).foregroundStyle(Color(pal.ink2))
                Spacer()
                Text("⌘Y 允许 · ⌘N 拒绝").font(.system(size: 10)).foregroundStyle(Color(pal.ink3))
            }
            Text(s.pendingDetail ?? s.pendingTool ?? "(请求权限)")
                .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Color(pal.ink2))
                .lineLimit(8).frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(pal.pill)))
                .padding(.top, 9)
            HStack(spacing: 6) {
                Button("Allow") { model.resolveLocalPermission(s.id, allow: true) }
                    .buttonStyle(InkButtonStyle(palette: pal))
                Button("Deny") { model.resolveLocalPermission(s.id, allow: false) }
                    .buttonStyle(PillButtonStyle(palette: pal, fontSize: 12))
                Button("打开会话") { model.openPendingSession() }
                    .buttonStyle(PillButtonStyle(palette: pal, fontSize: 12))
                Spacer()
            }
            .padding(.top, 11)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 12, leading: 16, bottom: 14, trailing: 16))
        .frame(width: model.bannerSize.width, height: model.bannerSize.height, alignment: .topLeading)
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
        cellHeader(
            model.captureKind == .focus ? "专注 → Helm" : "速记 → Helm",
            trailing: model.locked ? "● 输入中" : (model.captureKind == .focus ? nil : "TAB 切换模式"),
            trailingColor: model.locked ? Color(NomiTheme.g1) : nil)
        HStack(spacing: 6) {
            ForEach(CaptureKind.allCases) { kind in
                let on = model.captureKind == kind
                Button(kind.label) { model.captureKind = kind }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Color(model.nomi.onInk) : Color(model.nomi.ink2))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(on ? Color(model.nomi.ink) : Color(model.nomi.pill)))
            }
        }
        .padding(.top, 6)
        if model.captureKind == .focus {
            focusBody.padding(.top, 2)
        } else if model.captureKind == .journal {
            // 日记 = 每天一篇:今天卡 + 续写按钮开富文本弹层(2026-07-10 用户:
            // 去掉底部追加输入条,续写在弹层里写/改,支持加粗/斜体/高亮)。
            if model.journalEditing {
                journalEditor.padding(.top, 8)
            } else {
                journalTodayCard.padding(.top, 8)
                recentsSection.padding(.top, 6)
            }
            Spacer(minLength: 0)
        } else {
            // capin — full-width input on its own row (HTML .capin).
            TextField("", text: $model.captureText, prompt: Text(placeholder).foregroundStyle(Color(model.nomi.ink3)), axis: .vertical)
                .textFieldStyle(.plain).font(.system(size: 13)).foregroundStyle(Color(model.nomi.ink))
                .lineLimit(1...3).focused($captureFocused)
                .onSubmit { Task { await model.submit() } }
                .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(model.nomi.pill)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(model.locked ? Color(NomiTheme.g1).opacity(0.5) : .clear, lineWidth: 1.5))
                // 实测输入框高度,超出单行(~39pt 含 padding)的部分写回模型,
                // 面板预算跟着长——多行输入不再被面板底裁掉(2026-07-06 用户)。
                .background(InputHeightProbe { h in
                    model.captureInputExtraHeight = max(0, h - 39)
                })
                .padding(.top, 7)
            if !model.captureFiles.isEmpty { captureFilesRow.padding(.top, 8) }
            // caprow — hint + 发送(HTML .caprow)。时间/地点手选已删:发送后由
            // Helm 侧 AI 解析内容自动补(2026-07-05 用户)。
            HStack(alignment: .center, spacing: 8) {
                Text(captureHint).font(.system(size: 10.5)).foregroundStyle(Color(model.nomi.ink3))
                Spacer(minLength: 0)
                sendButton
            }
            .padding(.top, 10)
            statusLabel.padding(.top, 2)
            if model.captureKind == .ask, let answer = model.askAnswer {
                askAnswerCard(answer).padding(.top, 8)
            }
            recentsSection.padding(.top, 6)
        }
        Spacer(minLength: 0)
    }

    /// The 发送 button (HTML .sendb — plane glyph + kind-specific label, accent capsule).
    private var sendButton: some View {
        Button { Task { await model.submit() } } label: {
            HStack(spacing: 5) {
                Image(systemName: "paperplane.fill").font(.system(size: 10))
                Text(sendLabel).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(model.captureText.isEmpty ? Color(model.nomi.ink3) : .white)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Capsule().fill(model.captureText.isEmpty
                ? AnyShapeStyle(Color(model.nomi.pill)) : AnyShapeStyle(Nomi.gradientH)))
        }
        .buttonStyle(.plain).disabled(model.captureText.isEmpty)
    }

    private var sendLabel: String {
        if !model.captureFiles.isEmpty { return "发送并归档" }
        switch model.captureKind {
        case .ask: return "问"
        case .journal: return "续写"
        default: return "发送"
        }
    }

    private var captureHint: String {
        if !model.captureFiles.isEmpty { return "写点备注,发送 → Helm 帮你归档这些文件" }
        switch model.captureKind {
        case .ask: return "TAB 切换 · 问 Helm 大脑 · ⏎ 发送"
        case .journal: return "TAB 切换 · ⏎ 发送"
        default: return "TAB 切换 · ⏎ 发送 · AI 自动整理时间/地点"
        }
    }

    /// 专注 = 25min 番茄(用户拍板 Q4):初始即环(25:00 已暂停)+关联任务+
    /// 开始/暂停·重置·换任务;跑完自动落库。
    @ViewBuilder private var focusBody: some View {
        let pal = model.nomi
        HStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remain = model.focusRemaining(at: context.date)
                let frac = 1 - Double(remain) / Double(max(1, model.focusTotal))
                ZStack {
                    Circle().fill(AngularGradient(
                        stops: [.init(color: Color(NomiTheme.g1), location: 0),
                                .init(color: Color(NomiTheme.g2), location: max(0.001, frac)),
                                .init(color: Color(pal.pill), location: max(0.002, frac + 0.001)),
                                .init(color: Color(pal.pill), location: 1)],
                        center: .center, angle: .degrees(-90)))
                    Circle().fill(Color(pal.cardBG)).frame(width: 86, height: 86)
                        .overlay(
                            VStack(spacing: 1) {
                                Text(String(format: "%02d:%02d", remain / 60, remain % 60))
                                    .font(.system(size: 19, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Color(pal.ink))
                                Text(model.focusOn ? "专注中" : "已暂停")
                                    .font(.system(size: 9)).foregroundStyle(Color(pal.ink3))
                            })
                }
                .frame(width: 104, height: 104)
                // 跑完自动收番茄落库(focusOn 置 false 后不会重入)
                .onChange(of: remain == 0 && model.focusOn) { _, done in
                    if done { Task { await model.stopFocusAndRecord() } }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("关联任务").font(.system(size: 10)).foregroundStyle(Color(pal.ink3)).tracking(0.4)
                if focusEditing {
                    TextField("", text: $focusTaskDraft,
                              prompt: Text("这个番茄做什么…").foregroundStyle(Color(pal.ink3)))
                        .textFieldStyle(.plain).font(.system(size: 12.5)).foregroundStyle(Color(pal.ink))
                        .focused($focusTaskFocused)
                        .onSubmit { model.focusSetTask(focusTaskDraft); focusEditing = false }
                        .padding(EdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8))
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(pal.pill)))
                        .padding(.top, 4)
                } else {
                    Text(model.focusWhat.isEmpty ? "未设置 — 双击或点「换任务」" : model.focusWhat)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(model.focusWhat.isEmpty ? pal.ink3 : pal.ink))
                        .lineLimit(2).padding(.top, 4)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            focusTaskDraft = model.focusWhat
                            focusEditing = true
                            focusTaskFocused = true
                        }
                }
                HStack(spacing: 6) {
                    if model.focusOn {
                        Button("暂停") { model.pauseFocus() }.buttonStyle(PillButtonStyle(palette: pal, fontSize: 12))
                    } else {
                        Button("开始") { model.startFocus() }.buttonStyle(InkButtonStyle(palette: pal))
                    }
                    Button("重置") { model.resetFocus() }.buttonStyle(PillButtonStyle(palette: pal, fontSize: 12))
                    Button("换任务") {
                        focusTaskDraft = model.focusWhat
                        focusEditing = true
                        focusTaskFocused = true
                    }.buttonStyle(PillButtonStyle(palette: pal, fontSize: 12))
                }
                .padding(.top, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .onChange(of: focusTaskFocused) { _, f in
            if f { model.beginCapture() } else { model.endInteraction(); if focusEditing { model.focusSetTask(focusTaskDraft); focusEditing = false } }
        }
    }

    /// 日记今天卡:日期头 + 今天全文(可滚,不截断——2026-07-08 用户:要看到之前写的)。
    @ViewBuilder private var journalTodayCard: some View {
        let pal = model.nomi
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(journalDateLabel).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(pal.ink))
                Text("今天的日记").font(.system(size: 9.5)).foregroundStyle(Color(pal.ink3))
                Spacer()
                if let t = model.journalToday {
                    Text("\(t.count) 字").font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(Color(pal.ink2))
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(Color(pal.pill)))
                }
                // 续写:开富文本弹层(加粗/斜体/高亮)
                Button { model.openJournalEditor() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil").font(.system(size: 9))
                        Text("续写").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Nomi.gradientH))
                }
                .buttonStyle(.plain)
            }
            if let t = model.journalToday {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(t).font(.system(size: 11)).foregroundStyle(Color(pal.ink2))
                        .lineSpacing(3.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 104)
                .padding(.top, 6)
            } else {
                Text("还没动笔 — 写下今天第一句").font(.system(size: 11)).foregroundStyle(Color(pal.ink3))
                    .padding(.top, 6)
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .wcard(pal, dark: model.nomiDark)
        .task(id: model.captureKind) { await model.loadJournalToday() }
    }

    private var journalDateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 · EEE"
        return f.string(from: Date())
    }

    /// 续写富文本编辑器(面板内弹层):B/I/H 工具栏 + 编辑区 + 保存/取消。
    /// 保存 = 整篇替换 consolidate(model.saveJournalEditor)。
    @ViewBuilder private var journalEditor: some View {
        let pal = model.nomi
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Text(journalDateLabel).font(.system(size: 12, weight: .bold)).foregroundStyle(Color(pal.ink))
                Text("续写").font(.system(size: 9.5)).foregroundStyle(Color(pal.ink3))
                Spacer()
                fmtBtn("B", weight: .bold) { journalFormatter.wrap("**", "**") }
                fmtBtn("I", italic: true) { journalFormatter.wrap("*", "*") }
                fmtBtn("H", highlight: true) { journalFormatter.wrap("<mark>", "</mark>") }
            }
            JournalTextEditor(text: $model.journalEditText, formatter: journalFormatter, pal: pal)
                .frame(height: 136)
                .padding(.top, 8)
            HStack(spacing: 8) {
                Text("选中文字点 B / I / H").font(.system(size: 10)).foregroundStyle(Color(pal.ink3))
                Spacer()
                Button { model.cancelJournalEditor() } label: {
                    Text("取消").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color(pal.ink2))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(Color(pal.pill)))
                }
                .buttonStyle(.plain)
                Button { Task { await model.saveJournalEditor() } } label: {
                    Text("保存").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Nomi.gradientH))
                }
                .buttonStyle(.plain)
                .disabled(model.journalEditText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 10)
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .wcard(pal, dark: model.nomiDark)
    }

    /// B / I / H 格式钮(H = 高亮,黄底)。
    private func fmtBtn(_ title: String, weight: Font.Weight = .semibold, italic: Bool = false,
                        highlight: Bool = false, _ action: @escaping () -> Void) -> some View {
        let pal = model.nomi
        return Button(action: action) {
            Text(title).font(.system(size: 11, weight: weight)).italic(italic)
                .foregroundStyle(highlight ? Color(RGB(hex: "7a5b00")) : Color(pal.ink2))
                .frame(width: 24, height: 22)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(highlight ? Color(RGB(hex: "fff3bf")) : Color(pal.pill)))
        }
        .buttonStyle(.plain)
    }

    /// 拖入文件的附件 chip (HTML .attchip). Upload happens on send — TODO.
    private var captureFilesRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.captureFiles) { f in
                    HStack(spacing: 7) {
                        Text(f.ext).font(.system(size: 8, weight: .bold)).foregroundStyle(Color(model.nomi.ink2))
                            .frame(width: 26, height: 26)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(model.nomi.pill)))
                        Text(f.name).font(.system(size: 11)).foregroundStyle(Color(model.nomi.ink)).lineLimit(1)
                            .frame(maxWidth: 120, alignment: .leading)
                        Button { model.removeFile(f.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 8)).foregroundStyle(Color(model.nomi.ink2))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(model.nomi.pill).opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(model.nomi.hair), lineWidth: 1))
                }
            }
        }
    }

    // 时间/地点手选 chips 已删(2026-07-05):发送后由 Helm 侧 AI 解析补全。

    /// 最近 速记/日记/任务 (HTML .recents) — seed data; real recents need backend.
    /// ask 答案卡:大脑的回答 + 存速记。
    private func askAnswerCard(_ answer: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                SparkDot()
                Text("Helm 大脑").font(.system(size: 10.5)).foregroundStyle(Color(model.nomi.ink3))
            }
            ScrollView(.vertical, showsIndicators: false) {
                Text(answer).font(.system(size: 12)).foregroundStyle(Color(model.nomi.ink2))
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 96)
            HStack {
                Text("答 · \(model.askQuestion)").font(.system(size: 9))
                    .foregroundStyle(Color(model.nomi.ink3)).lineLimit(1)
                Spacer()
                Button { Task { await model.saveAskAsNote() } } label: {
                    Text("存速记").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(model.nomi.ink2))
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Color(model.nomi.pill)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 11, leading: 13, bottom: 11, trailing: 13))
        .wcard(model.nomi, dark: model.nomiDark)
    }

    /// 「最近」条:速记/日记走真数据(GET /api/notes);任务/问没有来源,不显示。
    @ViewBuilder private var recentsSection: some View {
        if model.captureKind == .note || model.captureKind == .journal {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    model.captureShowRecent.toggle()
                    if model.captureShowRecent { Task { await model.loadRecents() } }
                } label: {
                    HStack(spacing: 5) {
                        Text("▸").rotationEffect(.degrees(model.captureShowRecent ? 90 : 0))
                            .animation(.easeOut(duration: 0.2), value: model.captureShowRecent)
                        Text("最近\(model.captureKind.label)")
                    }
                    .font(.system(size: 10, weight: .bold)).tracking(0.4)
                    .foregroundStyle(Color(model.nomi.ink3))
                }
                .buttonStyle(.plain)
                if model.captureShowRecent {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if model.recentNotes.isEmpty {
                                Text("暂无").font(.system(size: 11)).foregroundStyle(Color(model.nomi.ink3))
                                    .frame(width: 160, height: 52, alignment: .topLeading)
                            } else {
                                ForEach(model.recentNotes) { n in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(model.captureKind.label).font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(Color(red: 0.1, green: 0.07, blue: 0.03))
                                            .padding(.horizontal, 6).padding(.vertical, 1)
                                            .background(RoundedRectangle(cornerRadius: 5).fill(accent))
                                        Text(n.content).font(.system(size: 11))
                                            .foregroundStyle(Color(model.nomi.ink)).lineLimit(1)
                                        Text(n.createdAt).font(.system(size: 9))
                                            .foregroundStyle(Color(model.nomi.ink3))
                                    }
                                    .frame(width: 160, alignment: .topLeading)
                                    .padding(.horizontal, 11).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(Color(model.nomi.pill).opacity(0.55)))
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color(model.nomi.hair), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    // MARK: Resize handle (width only — height is auto per-view)
    //
    // Confirmed 2026-07-01: height fully follows the active module (HTML
    // viewHeight); only the width stays user-adjustable.

    @State private var resizeHover = false

    private var resizeHandle: some View {
        Image(systemName: "arrow.left.and.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(resizeHover ? 0.5 : 0))  // 悬停才现身,不当牛皮癣
            .animation(.easeOut(duration: 0.15), value: resizeHover)
            .onHover { resizeHover = $0 }
            .padding(8)
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
        case .waitingPermission, .waitingQuestion: .orange
        case .idle: .white.opacity(0.55)
        case .ended: .white.opacity(0.35)
        }
    }

    private func phaseShort(_ phase: LocalSession.Phase) -> String {
        switch phase {
        case .running: "运行中 ›"
        case .waitingPermission: "待批准 ›"
        case .waitingQuestion: "待作答 ›"
        case .idle: "空闲 ›"
        case .ended: "结束"
        }
    }

    private var placeholder: String {
        switch model.captureKind {
        case .note: "随手记一笔…"
        case .journal: "续写今天 — 回车追加到今天这篇…"
        case .focus: "我现在在做什么…"
        case .ask: "问问 Helm 大脑…"
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch model.captureStatus {
        case .idle: EmptyView()
        case .sending: Text("发送中…").font(.system(size: 10)).foregroundStyle(Color(model.nomi.ink3))
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
struct ShineText: View {
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
        Text(text).font(font).foregroundStyle(Color(white: 0.55, opacity: 0.9)).lineLimit(1)  // 中性灰,双模式可读
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

/// A subtle fixed-offset slide + fade — matches the HTML `slideTo`/`slideDev`
/// feel (translate by a few dozen px, not the full frame width like `.move`).
private struct SlideOffsetModifier: ViewModifier {
    var dx: CGFloat
    var dy: CGFloat
    var faded: Bool
    func body(content: Content) -> some View {
        content.offset(x: dx, y: dy).opacity(faded ? 0 : 1)
    }
}

private extension AnyTransition {
    static func notchSlide(dx: CGFloat, dy: CGFloat) -> AnyTransition {
        .modifier(
            active: SlideOffsetModifier(dx: dx, dy: dy, faded: true),
            identity: SlideOffsetModifier(dx: 0, dy: 0, faded: false))
    }
}

/// The HTML `.cstar` — a slowly spinning ✻ that marks a running agent.
struct SpinningStar: View {
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
                    RoundedRectangle(cornerRadius: 2, style: .continuous).fill(color).opacity(0.5)
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

/// 量子视图高度的探针(background 用):抽成独立 View 免得长修饰链类型检查歧义。
private struct InputHeightProbe: View {
    let onHeight: (Double) -> Void
    var body: some View {
        GeometryReader { g in
            Color.clear.onChange(of: g.size.height, initial: true) { _, h in
                onHeight(h)
            }
        }
    }
}
