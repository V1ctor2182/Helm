import Foundation
import Observation

/// Observable state behind the notch UI. m1 added the backend connection; m2
/// adds quick-capture (速记/日记/任务) straight from the notch into Helm.
@MainActor
@Observable
public final class NotchModel {
    public private(set) var connection: ConnectionState = .unknown

    /// Whether the notch is expanded into the 2×2 panel (hover-driven).
    public var expanded = false
    /// Interaction lock: while set, the panel ignores hover-collapse and becomes
    /// key (keyboard). Entered by clicking the capture cell (速记) or answering an
    /// agent. Left on send / Esc / click-away.
    public var locked = false
    public var captureKind: CaptureKind = .note
    public var captureText = ""
    public private(set) var captureStatus: CaptureStatus = .idle

    // Capture extras (HTML S.taskTo / showRecent).
    /// For a task: keep it for myself (notes) or hand it to an agent (tasks).
    public var taskTarget: TaskTarget = .me
    /// Whether the "最近" recents strip is expanded (affects panel height).
    public var captureShowRecent = false
    /// Extra height of the vertical-axis input beyond one line (App 实测写入,
    /// 面板预算跟着长——多行输入不再被面板底裁掉;clamp 防失控)。
    public var captureInputExtraHeight: Double = 0 {
        didSet {
            // @Observable 把属性改写成计算属性,didSet 里无条件自赋值会
            // setter→didSet 无限递归(SIGSEGV);只在越界时收敛一次。
            let clamped = min(max(captureInputExtraHeight, 0), 60)
            if captureInputExtraHeight != clamped { captureInputExtraHeight = clamped }
        }
    }
    /// Files dragged onto the notch, staged for the capture (HTML S.files).
    public private(set) var captureFiles: [CaptureFile] = []
    private var fileSeq = 0

    /// Stage dropped files and switch to capture (HTML addFiles / drop handler).
    public func addFiles(_ names: [String]) {
        for name in names {
            fileSeq += 1
            let ext = String((name as NSString).pathExtension.uppercased().prefix(4))
            captureFiles.append(CaptureFile(id: "\(fileSeq)", name: name, ext: ext.isEmpty ? "FILE" : ext))
        }
        module = .files  // NOMI:拖拽暂存进 shelf(旧行为进速记页)
        expanded = true
    }

    public func removeFile(_ id: String) { captureFiles.removeAll { $0.id == id } }

    /// Cycle the capture kind (HTML: TAB in 速记 cycles note→journal→task→focus→ask).
    public func cycleCaptureKind(_ direction: Int = 1) {
        let all = CaptureKind.allCases
        let i = all.firstIndex(of: captureKind) ?? 0
        captureKind = all[((i + direction) % all.count + all.count) % all.count]
    }

    // Focus — 25min 番茄倒计时(2026-07-07 用户拍板 Q4:初始即环+开始/重置/换任务)。
    // 剩余从 startedAt+banked 推导,UI tick 不写状态;跑完/重置有进度才落库。
    public private(set) var focusOn = false        // 计时进行中
    public private(set) var focusWhat = ""
    public var focusTotal = 25 * 60                // 秒
    public private(set) var focusBanked = 0        // 暂停前已累计的秒数
    public private(set) var focusStartedAt = Date()

    /// 已专注秒数(banked + 本段进行中)。
    public func focusElapsed(at now: Date = Date()) -> Int {
        focusBanked + (focusOn ? max(0, Int(now.timeIntervalSince(focusStartedAt))) : 0)
    }

    /// 剩余秒数(0 = 该收番茄了)。
    public func focusRemaining(at now: Date = Date()) -> Int {
        max(0, focusTotal - focusElapsed(at: now))
    }

    /// 开始/继续。任务名为空时从速记输入顺手带一个(有就清掉输入)。
    public func startFocus() {
        guard !focusOn else { return }
        if focusWhat.isEmpty {
            let what = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !what.isEmpty { focusWhat = what; captureText = "" }
        }
        focusStartedAt = Date()
        focusOn = true
        locked = false
    }

    /// 暂停:把本段进账,停表。
    public func pauseFocus(at now: Date = Date()) {
        guard focusOn else { return }
        focusBanked += max(0, Int(now.timeIntervalSince(focusStartedAt)))
        focusOn = false
    }

    /// 归零(不落库);换任务/放弃用。
    public func resetFocus() {
        focusOn = false
        focusBanked = 0
    }

    public func focusSetTask(_ t: String) {
        focusWhat = t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 停表归零;返回本轮分钟数(min 1),任务名保留可再来一轮。
    @discardableResult public func stopFocus(at now: Date = Date()) -> Int {
        let minutes = max(1, Int((Double(focusElapsed(at: now)) / 60).rounded()))
        focusOn = false
        focusBanked = 0
        return minutes
    }

    /// 停止并落库(kind=focus 的 note,记录页·日记时间线可见)。跑完 25:00 或
    /// 用户主动收都走这里。
    public func stopFocusAndRecord(at now: Date = Date()) async {
        let what = focusWhat.isEmpty ? "专注" : focusWhat
        let minutes = stopFocus(at: now)
        captureStatus = .sending
        do {
            try await backend.createNote(
                content: "专注 \(minutes) 分钟 · \(what)", kind: "focus",
                journalDate: Self.today())
            captureStatus = .sent
        } catch {
            captureStatus = .failed
        }
    }

    // ── ask(问大脑)+ 最近条 ────────────────────────────────────
    public private(set) var askAnswer: String?
    public private(set) var askQuestion = ""
    public private(set) var recentNotes: [RecentNote] = []

    // MARK: 本地端口(App lsof 探测)

    public private(set) var localPorts: [PortInfo] = []
    /// App 注入的探测器(纯 Core 不碰 Process);nil = 未接线,页面显示探测不可用。
    public var portsProvider: (@Sendable () async -> [PortInfo])?
    public private(set) var portsRefreshing = false

    /// 进入端口子页时刷新一次(探测 ~百毫秒,后台跑)。
    public func refreshLocalPorts() async {
        guard let portsProvider, !portsRefreshing else { return }
        portsRefreshing = true
        localPorts = await portsProvider().sorted { $0.port < $1.port }
        portsRefreshing = false
    }

    // MARK: 剪贴板历史(App watcher 喂入)与暂存 shelf 动作

    public private(set) var clipboardHistory: [ClipItem] = []
    private var clipSeq = 0

    /// 记入剪贴板历史:连续重复不重记,新的在前,只留 5 条。
    public func recordClipboard(_ text: String, at now: Date = Date()) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, clipboardHistory.first?.text != t else { return }
        clipSeq += 1
        clipboardHistory.insert(ClipItem(id: "c\(clipSeq)", text: t, at: now), at: 0)
        if clipboardHistory.count > 5 { clipboardHistory = Array(clipboardHistory.prefix(5)) }
    }

    /// 剪贴板条目存速记(真通道:createNote)。
    public func saveClipToNote(_ item: ClipItem) async {
        captureStatus = .sending
        do {
            try await backend.createNote(content: item.text, kind: "note", journalDate: nil)
            captureStatus = .sent
        } catch { captureStatus = .failed }
    }

    /// shelf 文件「上传到记录」:文件名折进 note(真文件上传等附件 schema,同速记页做法),成功后移出 shelf。
    public func uploadShelfFile(_ id: String) async {
        guard let f = captureFiles.first(where: { $0.id == id }) else { return }
        captureStatus = .sending
        do {
            try await backend.createNote(content: "附件: \(f.name)", kind: "note", journalDate: nil)
            removeFile(id)
            captureStatus = .sent
        } catch { captureStatus = .failed }
    }

    /// 日历 addev:无建事件 API(契约不动)→ 建 agent 任务让 AI 解析时间加事件。
    public func addEventViaAgent(_ text: String) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        captureStatus = .sending
        do {
            try await backend.createTask(prompt: "加日历事件:\(t)")
            captureStatus = .sent
        } catch {
            captureStatus = .failed
        }
    }

    /// 总览 quickcap:一条速记直发后端,不动速记页的 kind/文本状态。
    public func quickNote(_ text: String) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        captureStatus = .sending
        do {
            try await backend.createNote(content: t, kind: "note", journalDate: nil)
            captureStatus = .sent
        } catch {
            captureStatus = .failed
        }
    }

    /// 把上一问答存成速记。
    public func saveAskAsNote() async {
        guard let a = askAnswer, !askQuestion.isEmpty else { return }
        try? await backend.createNote(
            content: "问:\(askQuestion)\n答:\(a)", kind: "note", journalDate: nil)
        captureStatus = .sent
    }

    /// 「最近」条:速记/日记走真数据(其余 kind 无来源,视图隐藏该条)。
    public func loadRecents() async {
        let kind = captureKind == .journal ? "journal" : "note"
        recentNotes = (try? await backend.recentNotes(kind: kind, limit: 3)) ?? []
    }

    /// 日记「今天卡」正文:今天的 journal 全文(多段按时间拼接;无则 nil)。
    public private(set) var journalToday: String?

    public func loadJournalToday(now: Date = Date()) async {
        let notes = (try? await backend.recentNotes(kind: "journal", limit: 10)) ?? []
        let today = Self.dayString(now)
        let todays = notes.filter { $0.createdAt.hasPrefix(today) }.reversed()
        let joined = todays.map(\.content).joined(separator: "\n\n")
        journalToday = joined.isEmpty ? nil : joined
    }

    static func dayString(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    // MARK: Module switching (dock + view), ported from helm-notch-pro.html

    /// The module shown in the expanded panel (HTML `S.view`).
    public var module: NotchModule = .dashboard
    /// The Dev module's active sub-section (HTML `S.devSec`).
    public var agentPage: AgentPage = .sessions
    /// Direction of the last module switch — drives the slide-in transition
    /// (HTML `slideTo(dir)`): true = forward (new enters from the right).
    public private(set) var moduleSwitchForward = true
    /// Direction of the last Dev sub-page change — drives the vertical slide
    /// (HTML `slideDev(dir)`): true = down (new enters from the bottom).
    public private(set) var agentPageForward = true
    /// The player the transport controls (HTML `S.mediaSrc`).
    public private(set) var mediaSource: MediaSource = .system

    /// Cycle to the next media source (HTML `srccycle`), wrapping around.
    public func cycleMediaSource() {
        let all = MediaSource.allCases
        let i = all.firstIndex(of: mediaSource) ?? 0
        mediaSource = all[(i + 1) % all.count]
    }

    // MARK: Calendar view state (HTML S.calExpand / S.calSel / S.calOff)

    /// `true` = month grid, `false` = week strip (HTML `S.calExpand`, default month).
    public var calMonthView = true
    /// Months away from the current month, for ‹ › nav (HTML `S.calOff`).
    public var calMonthOffset = 0
    /// The selected day-of-month for the agenda (HTML `S.calSel`).
    public var calSelectedDay = Calendar.current.component(.day, from: Date())

    public func calSelectDay(_ day: Int) { calSelectedDay = day }
    public func calSetMonthView(_ month: Bool) { calMonthView = month }
    public func calToday() { calMonthOffset = 0 }
    public func calPrevMonth() { calMonthOffset -= 1 }
    public func calNextMonth() { calMonthOffset += 1 }

    // MARK: Per-view height (HTML viewHeight() + NTOP)

    /// Height of the top bar, added on top of every view budget (HTML `NTOP`).
    public static let topBarHeight: Double = 34  // NOMI toprow(=折叠条高)

    /// The view+dock budget for the current module (HTML `viewHeight()` / `VH`).
    /// Each module is as tall as its content needs — no big black void.
    public func viewHeight() -> Double {
        switch module {
        case .dashboard: 280  // bento+quickcap+dock(2026-07-07 用户:重叠)
        case .media: 300  // 更宽更矮(2026-07-07 用户):560 宽腾给歌词
        case .calendar: 260  // NOMI 周条+事件+addev(月视图随稿退役)
        case .files: 280  // dropzone+shelf+剪贴板段
        case .agents:
            switch agentPage {
            // NOMI 卡片比旧行高;详情页(prompt+最后回复+回复框)最高。
            case .sessions: selectedLocalSessionID != nil ? 316 : 260
            case .ports: 260
            case .prs: 300
            }
        // Tightened vs the HTML prototype — the Swift content is more compact, so
        // the taller HTML budgets left too much empty space below (device feedback).
        // 删掉时间/地点行后内容更矮,预算跟着收(2026-07-05 用户:任务下面空太大)。
        // 预算含 dock(~54):note 208 / task +24(target 行) / ask+answer 322。
        // 多行输入时加 captureInputExtraHeight(App 实测),面板随输入框长。
        // NOMI 胶囊/输入盒都比 ORAGE 高一档,预算整体上调(2026-07-07 用户:被 clip)。
        case .capture:
            // 任务 kind 已随稿去除(2026-07-08 用户:任务只在 Helm,速记 AI 分诊建);
            // 日记 = 今天卡(全文可滚)+续写,预算更高。
            captureKind == .focus
                ? 240
                : (captureKind == .ask && askAnswer != nil
                    ? 340 + captureInputExtraHeight
                    : (captureShowRecent
                        ? min(360, (captureKind == .journal ? 300 : 232) + 64)
                        : (captureKind == .journal ? 300 : 232)) + captureInputExtraHeight)
        }
    }

    /// Total expanded panel height for the current view (HTML `--eh`).
    public var autoExpandedHeight: Double { viewHeight() + Self.topBarHeight }

    /// 展开壳宽:媒体页放宽到 560(歌词要呼吸,2026-07-07 用户),其余 440。
    public var expandedShellWidth: Double { module == .media ? 560 : expandedWidth }

    /// Select a module directly (HTML dock click). Slide direction is inferred
    /// from the dock index delta. Entering Dev resets to its first sub-section.
    public func selectModule(_ m: NotchModule) {
        let dock = NotchModule.dock
        let from = dock.firstIndex(of: module) ?? 0
        let to = dock.firstIndex(of: m) ?? from
        setModule(m, forward: to >= from)
    }

    /// Cycle the docked modules left/right with wrap-around (HTML
    /// `switchModule(dir)`). `media` is excluded — it is a zoom target only.
    public func switchModule(_ direction: Int) {
        let dock = NotchModule.dock
        let count = dock.count
        let i = dock.firstIndex(of: module) ?? 0
        setModule(dock[((i + direction) % count + count) % count], forward: direction > 0)
    }

    private func setModule(_ m: NotchModule, forward: Bool) {
        moduleSwitchForward = forward
        module = m
        if m == .agents { agentPage = .sessions } else { selectedLocalSessionID = nil }
        // Leaving 速记 ends the capture lock so hover-away can collapse again.
        if m != .capture { locked = false }
    }

    /// 智能体子页上下滑翻页(HTML .swipe snap)。Clamps at the ends — no wrap.
    public func switchAgentPage(_ direction: Int) {
        let all = AgentPage.allCases
        guard let i = all.firstIndex(of: agentPage) else { return }
        let next = i + direction
        guard next >= 0, next < all.count else { return }
        agentPageForward = direction > 0
        agentPage = all[next]
    }

    /// 跳到某张智能体子页(sdot 点击);推断滑动方向。
    public func selectAgentPage(_ s: AgentPage) {
        let all = AgentPage.allCases
        let from = all.firstIndex(of: agentPage) ?? 0
        let to = all.firstIndex(of: s) ?? from
        agentPageForward = to >= from
        agentPage = s
    }

    // MARK: NOMI theme (深默认+浅色,helm-notch-nomi.html)

    /// 深/浅面板。NOMI 重塑后这是唯一的模式开关;渐变 accent 不随它变。
    public var nomiDark = true
    /// 当前成套色板 — 视图只从这里取色,禁止单点混用两套。
    public var nomi: NomiPalette { nomiDark ? .dark : .light }

    // MARK: Theme (daily-rotating accent — 旧 ORAGE 皮,NOMI 转正后退役备用)

    /// Notch background material (HTML MATS). Default black keeps the current look.
    public var backgroundMaterial: NotchMaterial = .black { didSet { refreshTheme() } }
    /// 每天随机一套 (HTML cfg.dailytheme): a day-seeded material + accent, refreshed
    /// on midnight rollover. When on, it owns the theme (overrides mode/material).
    public var dailyRandomTheme = false { didSet { refreshTheme() } }
    /// Guards `refreshTheme` re-entrancy (it assigns material, whose didSet re-calls it).
    private var applyingTheme = false
    public var themeMode: ThemeMode = .daily { didSet { refreshTheme() } }
    public var fixedColorIndex = 0 { didSet { refreshTheme() } }
    /// The current accent color (recomputed each poll so it flips at midnight).
    public private(set) var accent: RGB = Theme.accent(for: Date(), mode: .daily)

    // MARK: Panel geometry (user-resizable, persisted by the controller)

    /// Detected physical notch width in points (set by the controller).
    public var notchWidth: Double = 200
    public var expandedWidth: Double = NomiTheme.openWidth  // 440,NOMI .shell.open
    public var expandedHeight: Double = 268

    /// Agent runs Helm knows about (backend orchestration).
    public private(set) var agents: [AgentRun] = []

    /// Locally-watched Claude Code sessions (hook+bridge). Primary source for the
    /// 本机 agent cell.
    public private(set) var localSessions: [LocalSession] = []

    /// Set by the controller — routes a permission verdict back to the bridge.
    /// `updatedInput` (tool_input JSON) rides along for question answers.
    public var resolvePermission: (@MainActor (_ session: String, _ allow: Bool, _ updatedInput: String?) -> Void)?

    /// 「打开会话」按下后压住横幅,改在智能体页里处理(新请求/解决后复位)。
    public var bannerSuppressed = false

    /// banner 上的「打开会话」:压横幅 → 智能体页会话列表(permcard 在列表里)。
    public func openPendingSession() {
        bannerSuppressed = true
        selectedLocalSessionID = nil
        selectModule(.agents)
        expanded = true
    }

    /// Session opened in the Dev/Agents detail view (nil = list).
    public var selectedLocalSessionID: String?
    public var selectedLocalSession: LocalSession? {
        selectedLocalSessionID.flatMap { id in localSessions.first { $0.id == id } }
    }

    /// Set by the app — opens the settings window (gear button in the panel).
    public var openSettings: (@MainActor () -> Void)?

    public var localActiveCount: Int { localSessions.lazy.filter(\.isActive).count }
    /// Permission banner 高度随内容走:头 40 + 标题 25 + 正文行数 + 按钮区 60。
    /// 定高 208 在一行 detail 时底下剩一大块黑(2026-07-03 用户反馈)。
    public var bannerSize: CGSize {
        let w = NomiTheme.bannerWidth  // NOMI bannermode 460
        guard let s = localSessions.first(where: { $0.needsAttention }) else {
            return CGSize(width: w, height: 208)
        }
        // 选择题横幅:头 40 + 每题(题面 ~22 + 每选项 ~30) + 提交区 56。
        if let q = s.question {
            var h = 40.0 + 56.0
            for item in q.items {
                h += 24 + Double(item.options.count) * 30
                if !item.header.isEmpty { h += 16 }
            }
            return CGSize(width: w, height: min(560, max(208, h)))
        }
        let detail = s.pendingDetail ?? s.pendingTool ?? ""
        // 显式换行 + 长行折行估算(monospaced 10.5pt,460 宽约容 56 字符)
        let lines = detail.split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { $0 + max(1, Int(ceil(Double($1.count) / 56.0))) }
        let clamped = min(8, max(1, lines))
        return CGSize(width: w, height: CGFloat(112 + clamped * 16))
    }

    /// 折叠态两翼宽度随内容走(2026-07-03 用户:折叠态太宽)。
    /// 左翼:媒体播放/专注要放标题,空闲只有 ● Helm;右翼:日程要放"10:00 站会",
    /// 计数徽章/空闲一个点就够。原一刀切 notch+200 在空闲时两边全是黑。
    public var collapsedLeftWing: CGFloat {
        if focusOn { return 120 }
        if nowPlaying != nil { return 130 }
        return 58
    }

    public var collapsedRightWing: CGFloat {
        if focusOn { return 70 }
        let waiting = localSessions.contains { $0.needsAttention }
        let running = localSessions.contains { $0.phase == .running }
        if waiting || running { return 48 }
        if !events.isEmpty { return 120 }
        return 40
    }

    /// 折叠条实测宽度(视图量完回填);nil=首帧未量,先用估算。
    public var collapsedMeasuredWidth: CGFloat?

    public var collapsedWidth: CGFloat {
        let floor = CGFloat(NomiTheme.foldedWidth)  // NOMI 折叠条设计宽 310
        let estimate = CGFloat(notchWidth) + collapsedLeftWing + collapsedRightWing
        guard let m = collapsedMeasuredWidth else { return max(estimate, floor) }
        // 实测为准,但不窄于设计宽/物理刘海+两侧最小呼吸
        return max(m, CGFloat(notchWidth) + 76, floor)
    }

    public var localAttentionCount: Int { localSessions.lazy.filter(\.needsAttention).count }

    /// Running or blocked agents — surfaced on the collapsed pill.
    public var activeAgentCount: Int { agents.lazy.filter(\.isActive).count }
    /// Agents blocked on a permission decision (needs the user).
    public var attentionCount: Int { agents.lazy.filter(\.needsAttention).count }

    /// Today's calendar events (m2 — empty until the API is wired).
    public private(set) var events: [CalEvent] = []

    /// A near-term event popped as the reminder banner (HTML S.remind).
    public private(set) var reminder: EventReminder?
    private var dismissedReminderIDs: Set<String> = []

    /// Pop a reminder for a today event starting within the next 5 minutes
    /// (HTML's "现在开始"). Skips events already dismissed; one at a time.
    public func checkReminders(now: Date = Date()) {
        guard reminder == nil else { return }
        let cal = Calendar.current
        let nowMin = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        for ev in events where !dismissedReminderIDs.contains(ev.id) {
            guard let startMin = Self.startMinutes(ev.when) else { continue }
            let delta = startMin - nowMin
            if delta >= 0, delta <= 5 {
                reminder = EventReminder(id: ev.id, title: ev.summary, timeRange: ev.when)
                return
            }
        }
    }

    /// Leading "HH:mm" of an event's display string → minutes-of-day (nil for 全天).
    nonisolated static func startMinutes(_ when: String) -> Int? {
        let parts = when.prefix(5).split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    /// 忽略 — drop and don't re-fire for this event.
    public func dismissReminder() {
        if let r = reminder { dismissedReminderIDs.insert(r.id) }
        reminder = nil
    }
    /// 稍后 — drop but allow it to re-fire on a later check.
    public func snoozeReminder() { reminder = nil }
    /// 查看/加入 — treat like a dismiss (the caller opens the calendar).
    public func openReminder() { dismissReminder() }

    /// Current now-playing media (nil when nothing is playing / unavailable).
    public private(set) var nowPlaying: NowPlaying?
    /// Wall-clock time the current `nowPlaying` snapshot was captured — lets the
    /// UI advance the progress bar smoothly between 5s polls.
    public private(set) var nowPlayingFetchedAt = Date()

    private let backend: HelmBackend
    private let media: MediaController
    private var collapseTask: Task<Void, Never>?

    public init(backend: HelmBackend, media: MediaController = NoMediaController()) {
        self.backend = backend
        self.media = media
    }

    /// One poll tick: connection + agent runs + media + theme (midnight rollover).
    public func poll() async {
        refreshTheme()
        await refresh()
        await refreshAgents()
        await refreshEvents()
        await refreshMedia()
        checkReminders()
    }

    /// Refresh today's calendar events; keep the last list on error.
    public func refreshEvents() async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        if let evs = try? await backend.listEvents(start: start, end: end) {
            events = evs
        }
    }

    /// Recompute the accent for today, then nudge it to stay readable on the
    /// current background material (HTML contrast guarantee). When 每天随机一套 is
    /// on, a day-seeded material + accent takes over (HTML dailyRandTheme).
    public func refreshTheme() {
        guard !applyingTheme else { return }
        applyingTheme = true
        defer { applyingTheme = false }
        if dailyRandomTheme {
            let (m, idx) = Self.dailyThemeChoice(for: Date())
            backgroundMaterial = m          // didSet re-enters → guarded no-op
            themeMode = .fixed
            fixedColorIndex = idx
            accent = Theme.contrastSafeAccent(Theme.palette[idx], on: m)
        } else {
            let base = Theme.accent(for: Date(), mode: themeMode, fixedIndex: fixedColorIndex)
            accent = Theme.contrastSafeAccent(base, on: backgroundMaterial)
        }
    }

    /// 随机一套 (HTML `randomTheme`): a random material + a random palette accent.
    /// Contrast is guaranteed by `refreshTheme` → `contrastSafeAccent`.
    public func randomTheme() {
        dailyRandomTheme = false  // manual random overrides the daily-auto theme
        themeMode = .fixed
        fixedColorIndex = Int.random(in: 0..<Theme.palette.count)
        backgroundMaterial = NotchMaterial.allCases.randomElement() ?? .black  // didSet → refreshTheme
    }

    /// Deterministic per-day (material, palette index) — HTML `dailyRandTheme`'s
    /// `di`-seeded LCG (stable within a day, changes at midnight).
    nonisolated static func dailyThemeChoice(for date: Date) -> (NotchMaterial, Int) {
        let di = Theme.dayIndex(date)
        var seed = UInt64(UInt32(truncatingIfNeeded: di) &* 2_654_435_761) % 2_147_483_647
        if seed == 0 { seed = 1 }
        func rnd() -> Double { seed = (seed &* 48_271) % 2_147_483_647; return Double(seed) / 2_147_483_647 }
        let mats = NotchMaterial.allCases
        let m = mats[Int(rnd() * Double(mats.count)) % mats.count]
        let idx = Int(rnd() * Double(Theme.palette.count)) % Theme.palette.count
        return (m, idx)
    }

    /// Clamp + apply a user drag-resize of the expanded panel.
    public func resize(width: Double, height: Double) {
        expandedWidth = min(max(width, 480), 1000)
        expandedHeight = min(max(height, 230), 560)
    }

    // ── 歌词(换曲触发,内存缓存;fetcher 注入可测)──────────────────
    public private(set) var lyrics: Lyrics = .none
    public var lyricsFetcher = LyricsFetcher()
    private var lyricsCache: [String: Lyrics] = [:]
    private var lyricsTrackKey = ""

    /// Snapshot/预览专用:直接注入媒体+歌词状态(别在业务代码里用)。
    public func debugSetMedia(_ np: NowPlaying?, lyrics l: Lyrics) {
        nowPlaying = np
        nowPlayingFetchedAt = Date()
        lyrics = l
    }

    public func refreshMedia() async {
        var snapshot = await media.nowPlaying()
        // 暂停/状态切换时 MediaRemote 偶尔不回传 artwork——同一首歌就沿用上一帧,
        // 别让封面闪成 fallback 渐变(2026-07-04 用户:暂停会变绿一下)。
        if let new = snapshot, new.artworkBase64 == nil,
           let old = nowPlaying, old.title == new.title, old.artist == new.artist,
           old.artworkBase64 != nil {
            snapshot = NowPlaying(
                title: new.title, artist: new.artist, isPlaying: new.isPlaying,
                artworkBase64: old.artworkBase64,
                elapsed: new.elapsed, duration: new.duration)
        }
        nowPlaying = snapshot
        nowPlayingFetchedAt = Date()
        await refreshLyricsIfTrackChanged()
    }

    func refreshLyricsIfTrackChanged() async {
        guard let np = nowPlaying, !np.title.isEmpty else {
            lyrics = .none
            lyricsTrackKey = ""
            return
        }
        let key = "\(np.title)|\(np.artist)"
        if key == lyricsTrackKey { return }
        lyricsTrackKey = key
        if let hit = lyricsCache[key] {
            lyrics = hit
            return
        }
        lyrics = .none  // 取词期间先诚实显示无
        let got = await lyricsFetcher.fetch(title: np.title, artist: np.artist, duration: np.duration)
        // 异步回来时可能已换曲——只在还是同一首时落地
        if lyricsTrackKey == key {
            lyricsCache[key] = got
            lyrics = got
        }
    }

    /// Live playback position in seconds, advanced from the last poll while
    /// playing. `now` is passed in so a `TimelineView` can drive it each tick.
    public func livePosition(at now: Date = Date()) -> Double {
        guard let np = nowPlaying, let elapsed = np.elapsed else { return 0 }
        let advanced = np.isPlaying ? now.timeIntervalSince(nowPlayingFetchedAt) : 0
        let position = elapsed + max(0, advanced)
        if let duration = np.duration, duration > 0 { return min(position, duration) }
        return position
    }

    // 播控三连:命令本身 ~40ms,但轮询 5s 一跳——不做乐观更新的话
    // 图标要等下一跳才变脸(2026-07-03 用户:暂停有挺长延迟)。
    // 本地先翻状态,300ms 后立即回查校准(切歌 600ms,等新曲元数据就位)。
    public func playPause() {
        media.playPause()
        if let np = nowPlaying {
            nowPlaying = NowPlaying(
                title: np.title, artist: np.artist, isPlaying: !np.isPlaying,
                artworkBase64: np.artworkBase64,
                elapsed: livePosition(), duration: np.duration)
            nowPlayingFetchedAt = Date()
        }
        reconcileMedia(after: .milliseconds(300))
    }

    public func nextTrack() {
        media.nextTrack()
        reconcileMedia(after: .milliseconds(600))
    }

    public func previousTrack() {
        media.previousTrack()
        reconcileMedia(after: .milliseconds(600))
    }

    private func reconcileMedia(after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            await self?.refreshMedia()
        }
    }

    /// Poll the backend once and fold the result into `connection`.
    public func refresh() async {
        do {
            let health = try await backend.health()
            connection = .connected(version: health.version)
        } catch {
            connection = .disconnected
        }
    }

    /// Refresh the agent run list; keep the last list on error.
    public func refreshAgents() async {
        if let runs = try? await backend.listRuns() {
            agents = runs
        }
    }

    // MARK: Local Claude Code monitoring (bridge events)

    /// Fold one hook event into `localSessions`.
    public func applyHook(_ m: HookMessage) {
        let now = Date()
        switch m.event {
        case "SessionStart":
            upsert(m, phase: .running, now: now)
        case "UserPromptSubmit", "PostToolUse":
            upsert(m, phase: .running, now: now)
        case "PreToolUse", "Notification":
            // 挂起的权限/选择题不许被活动事件降级——PermissionRequest 静候期间
            // Claude 会紧跟一条 "needs your permission" 的 Notification,
            // 不挡住它横幅会闪现即消(2026-07-06 用户实测)。
            if let i = localSessions.firstIndex(where: { $0.id == m.session }),
               localSessions[i].needsAttention {
                localSessions[i].updatedAt = now
            } else {
                upsert(m, phase: .running, activity: activityLabel(m), now: now)
            }
        case "PermissionRequest":
            bannerSuppressed = false  // 新请求重新弹横幅
            // 选择题解析成功 → 独立的 waitingQuestion(notch 内可作答);
            // 解析不了照旧走 waitingPermission 允许/拒绝。
            let question = (m.tool == "AskUserQuestion" && m.toolInput != nil)
                ? QuestionPrompt.parse(toolInputJSON: m.toolInput!) : nil
            upsert(m, phase: question != nil ? .waitingQuestion : .waitingPermission,
                   activity: activityLabel(m), pendingTool: m.tool, pendingDetail: m.detail,
                   question: question, now: now)
        case "Stop":
            // turn 结束 ≠ 会话结束:CLI 还活着等下一条 prompt,进 idle 可回复。
            upsert(m, phase: .idle, now: now)
        case "SessionEnd":
            upsert(m, phase: .ended, now: now)
        case "SubagentStop":
            break  // 子 agent 收尾不改主会话状态
        default:
            break
        }
        prune(now: now)
    }

    /// User tapped 允许 / 拒绝 on a local session's permission card. Either way
    /// the CLI keeps going (deny 也会让 Claude 接着处理拒绝),so back to running.
    public func resolveLocalPermission(_ session: String, allow: Bool) {
        clearPending(session, phase: .running)
        resolvePermission?(session, allow, nil)
    }

    /// User submitted answers for an AskUserQuestion — allow the tool with the
    /// answers merged into its input (question text → answer string).
    public func resolveLocalQuestion(_ session: String, answers: [String: String]) {
        guard let i = localSessions.firstIndex(where: { $0.id == session }) else { return }
        let toolInput = localSessions[i].pendingToolInput ?? "{}"
        let updated = QuestionPrompt.mergeAnswers(answers, intoToolInputJSON: toolInput)
        clearPending(session, phase: .running)
        resolvePermission?(session, true, updated)
    }

    /// The parked hook connection died without a verdict — the user resolved it
    /// in the terminal (or the hook got killed). Drop the stale banner.
    public func hookDropped(_ session: String) {
        guard let i = localSessions.firstIndex(where: { $0.id == session }),
              localSessions[i].needsAttention else { return }
        clearPending(session, phase: .running)
    }

    private func clearPending(_ session: String, phase: LocalSession.Phase) {
        bannerSuppressed = false
        guard let i = localSessions.firstIndex(where: { $0.id == session }) else { return }
        localSessions[i].phase = phase
        localSessions[i].pendingTool = nil
        localSessions[i].pendingDetail = nil
        localSessions[i].pendingToolInput = nil
        localSessions[i].question = nil
        localSessions[i].updatedAt = Date()
    }

    private func activityLabel(_ m: HookMessage) -> String? {
        if let detail = m.detail, !detail.isEmpty { return detail }
        return m.tool
    }

    private func upsert(_ m: HookMessage, phase: LocalSession.Phase,
                        activity: String? = nil, pendingTool: String? = nil,
                        pendingDetail: String? = nil, question: QuestionPrompt? = nil,
                        now: Date) {
        if let i = localSessions.firstIndex(where: { $0.id == m.session }) {
            if let cwd = m.cwd, !cwd.isEmpty { localSessions[i].cwd = cwd }
            localSessions[i].phase = phase
            if let activity { localSessions[i].activity = activity }
            localSessions[i].pendingTool = pendingTool
            localSessions[i].pendingDetail = pendingDetail
            localSessions[i].pendingToolInput = pendingTool != nil ? m.toolInput : nil
            localSessions[i].question = question
            if let p = m.prompt, !p.isEmpty { localSessions[i].lastPrompt = p }
            if let a = m.assistant, !a.isEmpty { localSessions[i].lastAssistant = a }
            if let t = m.transcriptPath { localSessions[i].transcriptPath = t }
            if let t = m.term { localSessions[i].termProgram = t }
            if let t = m.tmuxPane { localSessions[i].tmuxPane = t }
            if let t = m.tmuxSocket { localSessions[i].tmuxSocket = t }
            localSessions[i].updatedAt = now
        } else {
            localSessions.append(LocalSession(
                id: m.session, cwd: m.cwd ?? "", phase: phase, activity: activity,
                pendingTool: pendingTool, pendingDetail: pendingDetail, updatedAt: now,
                question: question, lastPrompt: m.prompt, lastAssistant: m.assistant,
                transcriptPath: m.transcriptPath, termProgram: m.term,
                tmuxPane: m.tmuxPane, tmuxSocket: m.tmuxSocket))
            if pendingTool != nil { localSessions[localSessions.count - 1].pendingToolInput = m.toolInput }
        }
        localSessions.sort { a, b in
            if a.isActive != b.isActive { return a.isActive }  // active first
            return a.updatedAt > b.updatedAt                    // then newest first
        }
    }

    /// Drop dead sessions: ended after 90s, idle after 30min silence; cap length.
    private func prune(now: Date) {
        localSessions.removeAll {
            ($0.phase == .ended && now.timeIntervalSince($0.updatedAt) > 90)
                || ($0.phase == .idle && now.timeIntervalSince($0.updatedAt) > 1800)
        }
        if localSessions.count > 6 {
            localSessions = Array(localSessions.prefix(6))
        }
        if let sel = selectedLocalSessionID, !localSessions.contains(where: { $0.id == sel }) {
            selectedLocalSessionID = nil
        }
    }

    public func toggleExpanded() {
        expanded.toggle()
        if !expanded { captureStatus = .idle }
    }

    /// Hover-driven expand: open immediately on enter, collapse after a short
    /// grace period on exit so brief mouse slips don't flap the panel. A pending
    /// capture (non-empty text) keeps it open even if the pointer leaves.
    /// When set, the panel ignores hover (stays as-is) — debug/screenshot aid.
    public var hoverPinned = false

    public func hover(_ inside: Bool) {
        if hoverPinned { return }
        collapseTask?.cancel()
        if inside {
            expanded = true
            return
        }
        collapseTask = Task { [weak self] in
            // Small debounce so a brief pointer slip doesn't flap; HTML collapses
            // immediately on mouseleave, so keep this short (device feedback).
            try? await Task.sleep(for: .milliseconds(80))
            guard let self, !Task.isCancelled else { return }
            // Locked (mid-interaction) or with pending text → stay open.
            // Stay open only while locked, or while there's pending 速记 text AND
            // we're still on the 速记 module (switching away shouldn't pin it open).
            let heldByCapture = self.module == .capture && !self.captureText.isEmpty
            if !self.locked && !heldByCapture { self.collapse() }
        }
    }

    /// Click the 速记 cell → lock the panel open for keyboard input.
    public func beginCapture() {
        collapseTask?.cancel()
        expanded = true
        locked = true
    }

    /// Leave interaction mode (Esc / send / click-away) without forcing collapse.
    public func endInteraction() {
        locked = false
    }

    public func collapse() {
        collapseTask?.cancel()
        expanded = false
        locked = false
        captureStatus = .idle
    }

    /// Submit the current capture text to Helm via the kind's endpoint.
    /// 时间/地点不再手选——发送后由 Helm 侧 AI 解析内容自动补(2026-07-05 用户:
    /// 除日记外的记录都走 AI 优化+parse;TODO(ai-parse) 属 F6 阶段2)。
    public func submit() async {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var ext = ""
        // 拖进来的文件:名字折进内容(真文件上传等 journal 附件 schema,P2 在账)
        if !captureFiles.isEmpty {
            ext += "\n附件: " + captureFiles.map(\.name).joined(separator: ", ")
        }
        captureStatus = .sending
        do {
            switch captureKind {
            case .note:
                try await backend.createNote(content: text + ext, kind: "note", journalDate: nil)
            case .journal:
                try await backend.createNote(content: text + ext, kind: "journal", journalDate: Self.today())
                await loadJournalToday()  // 续写后今天卡立即刷新
            case .focus:
                return  // focus uses start/stop, not submit
            case .ask:
                // 真问大脑(POST /api/ask,走 Chat 配好的 provider)
                askQuestion = text
                askAnswer = nil
                let answer = try await backend.ask(text)
                askAnswer = answer
            }
            captureText = ""
            captureFiles = []
            captureStatus = .sent
        } catch {
            captureStatus = .failed
        }
    }

    /// Today's date as ISO `yyyy-MM-dd` in the local timezone.
    static func today() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
