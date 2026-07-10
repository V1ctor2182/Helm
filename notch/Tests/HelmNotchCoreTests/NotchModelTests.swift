import XCTest

@testable import HelmNotchCore

/// A fake backend so the core is tested with no real network. Records capture
/// calls for assertions (`@unchecked Sendable` — accessed only from the test's
/// MainActor, sequentially via `await`).
final class FakeBackend: HelmBackend, @unchecked Sendable {
    var healthResult: Result<Health, Error>
    var shouldFailCapture = false
    var runs: [AgentRun] = []
    var events: [CalEvent] = []
    var recents: [RecentNote] = []
    var journals: [RecentNote] = []
    private(set) var notes: [(content: String, kind: String, journalDate: String?)] = []
    private(set) var tasks: [String] = []

    init(healthResult: Result<Health, Error> = .success(Health(status: "ok", version: "0.0.1"))) {
        self.healthResult = healthResult
    }

    func health() async throws -> Health {
        try healthResult.get()
    }

    func listRuns() async throws -> [AgentRun] {
        runs
    }

    func recentNotes(kind: String, limit: Int) async throws -> [RecentNote] {
        recents
    }

    func journalNotes(date: String) async throws -> [RecentNote] {
        journals  // 服务端已按 journal_date 过滤,fake 直接回填
    }

    func listEvents(start: Date, end: Date) async throws -> [CalEvent] {
        events
    }

    func createNote(content: String, kind: String, journalDate: String?) async throws {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        notes.append((content, kind, journalDate))
    }

    private(set) var updated: [(id: Int, content: String)] = []
    private(set) var deleted: [Int] = []
    func updateNote(id: Int, content: String) async throws {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        updated.append((id, content))
    }
    func deleteNote(id: Int) async throws {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        deleted.append(id)
    }

    func createTask(prompt: String) async throws {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        tasks.append(prompt)
    }

    func ask(_ q: String) async throws -> String {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        asked.append(q)
        return "答:\(q)"
    }
    private(set) var asked: [String] = []
}

struct StubError: Error {}

/// Records media commands and serves a canned now-playing snapshot.
final class FakeMedia: MediaController, @unchecked Sendable {
    var current: NowPlaying?
    private(set) var commands: [String] = []

    init(current: NowPlaying? = nil) { self.current = current }

    func nowPlaying() async -> NowPlaying? { current }
    func playPause() { commands.append("playPause") }
    func nextTrack() { commands.append("next") }
    func previousTrack() { commands.append("prev") }
}

final class NotchModelTests: XCTestCase {
    @MainActor
    func testConnectsOnHealthyBackend() async {
        let model = NotchModel(backend: FakeBackend())
        await model.refresh()
        XCTAssertEqual(model.connection, .connected(version: "0.0.1"))
    }

    @MainActor
    func testDisconnectsWhenBackendErrors() async {
        let model = NotchModel(backend: FakeBackend(healthResult: .failure(StubError())))
        await model.refresh()
        XCTAssertEqual(model.connection, .disconnected)
    }

    @MainActor
    func testStartsUnknownAndCollapsed() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.connection, .unknown)
        XCTAssertFalse(model.expanded)
        XCTAssertEqual(model.captureStatus, .idle)
    }

    // MARK: 日记续写(2026-07-10 用户:今天卡续写按钮开富文本弹层,整篇替换)

    @MainActor
    func testOpenJournalEditorSeedsTodayText() async {
        let fake = FakeBackend()
        fake.journals = [RecentNote(id: 5, content: "早上定了稿", kind: "journal", createdAt: "")]
        let model = NotchModel(backend: fake)
        await model.loadJournalToday()
        model.openJournalEditor()
        XCTAssertTrue(model.journalEditing)
        XCTAssertEqual(model.journalEditText, "早上定了稿")   // 预填今天整篇
        XCTAssertEqual(model.journalTodayIds, [5])
    }

    @MainActor
    func testSaveEditorConsolidatesIntoFirstAndDeletesRest() async {
        let fake = FakeBackend()
        fake.journals = [
            RecentNote(id: 5, content: "早上", kind: "journal", createdAt: ""),
            RecentNote(id: 6, content: "下午", kind: "journal", createdAt: ""),
        ]
        let model = NotchModel(backend: fake)
        await model.loadJournalToday()
        model.openJournalEditor()
        model.journalEditText = "早上\n\n下午\n\n加粗**重点**"
        await model.saveJournalEditor()
        // 整篇替换 → 改第一条,删其余,不新建
        XCTAssertEqual(fake.updated.map(\.id), [5])
        XCTAssertEqual(fake.updated.first?.content, "早上\n\n下午\n\n加粗**重点**")
        XCTAssertEqual(fake.deleted, [6])
        XCTAssertTrue(fake.notes.isEmpty)
        XCTAssertFalse(model.journalEditing)
    }

    @MainActor
    func testSaveEditorCreatesWhenNoTodayEntry() async {
        let fake = FakeBackend()   // 今天没写过
        let model = NotchModel(backend: fake)
        await model.loadJournalToday()
        model.openJournalEditor()
        XCTAssertEqual(model.journalEditText, "")
        model.journalEditText = "今天第一段"
        await model.saveJournalEditor()
        XCTAssertEqual(fake.notes.map(\.content), ["今天第一段"])
        XCTAssertEqual(fake.notes.first?.kind, "journal")
        XCTAssertTrue(fake.updated.isEmpty)
    }
}

/// Module/dock state machine ported from helm-notch-pro.html.
final class NotchModuleTests: XCTestCase {
    @MainActor
    func testStartsOnDashboard() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.module, .dashboard)
        XCTAssertEqual(model.agentPage, .sessions)
    }

    @MainActor
    func testDockOrderExcludesMedia() {
        XCTAssertEqual(NotchModule.dock, [.dashboard, .capture, .calendar, .agents, .files])
        XCTAssertFalse(NotchModule.dock.contains(.media))
    }

    @MainActor
    func testSwitchModuleWrapsForward() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .files  // last in the dock
        model.switchModule(1)
        XCTAssertEqual(model.module, .dashboard)  // wraps to first
    }

    @MainActor
    func testSwitchModuleWrapsBackward() {
        let model = NotchModel(backend: FakeBackend())
        model.switchModule(-1)  // from dashboard (first)
        XCTAssertEqual(model.module, .files)  // wraps to last
    }

    @MainActor
    func testSwitchModuleFromMediaFallsBackToDockStart() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .media  // not in the dock
        model.switchModule(1)
        XCTAssertEqual(model.module, .capture)  // index 0 + 1
    }

    @MainActor
    func testBackgroundMaterialDefaultsToBlack() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.backgroundMaterial, .black)
        model.backgroundMaterial = .darkGlass
        XCTAssertEqual(model.backgroundMaterial, .darkGlass)
    }

    func testContrastRatioSanity() {
        let white = RGB(r: 1, g: 1, b: 1), black = RGB(r: 0, g: 0, b: 0)
        XCTAssertEqual(Theme.contrast(white, black), 21, accuracy: 0.3)
    }

    func testContrastSafeAccentIsNoopOnBlack() {
        let sky = RGB(hex: "5EA0FF")  // already reads on the near-black notch
        let safe = Theme.contrastSafeAccent(sky, on: .black)
        XCTAssertEqual(safe.r, sky.r, accuracy: 0.0001)
        XCTAssertEqual(safe.g, sky.g, accuracy: 0.0001)
        XCTAssertEqual(safe.b, sky.b, accuracy: 0.0001)
    }

    func testContrastSafeAccentDarkensOnLightGlass() {
        let amber = RGB(hex: "FFC53D")  // light accent, unreadable on 白玻璃
        let bg = Theme.materialBackground(.lightGlass)
        XCTAssertLessThan(Theme.contrast(amber, bg), 3.2)          // originally poor
        let safe = Theme.contrastSafeAccent(amber, on: .lightGlass)
        XCTAssertGreaterThanOrEqual(Theme.contrast(safe, bg), 3.0) // now readable
        XCTAssertLessThan(Theme.luminance(safe), Theme.luminance(amber))  // darkened
    }

    func testDailyThemeChoiceIsDeterministicPerDay() {
        let d1 = Date(timeIntervalSince1970: 1_800_000_000)  // some fixed day
        let a = NotchModel.dailyThemeChoice(for: d1)
        let b = NotchModel.dailyThemeChoice(for: d1.addingTimeInterval(3600))  // same day
        XCTAssertEqual(a.0, b.0)
        XCTAssertEqual(a.1, b.1)
        let c = NotchModel.dailyThemeChoice(for: d1.addingTimeInterval(86_400 * 3))  // 3 days later
        XCTAssertTrue(a.0 != c.0 || a.1 != c.1)  // different day → (very likely) different set
    }

    @MainActor
    func testDailyRandomThemeIsContrastSafeAndOwnsTheme() {
        let model = NotchModel(backend: FakeBackend())
        model.dailyRandomTheme = true
        XCTAssertEqual(model.themeMode, .fixed)
        let bg = Theme.materialBackground(model.backgroundMaterial)
        XCTAssertGreaterThanOrEqual(Theme.contrast(model.accent, bg), 3.0)
    }

    @MainActor
    func testRandomThemeAlwaysContrastSafe() {
        let model = NotchModel(backend: FakeBackend())
        for _ in 0..<24 {
            model.randomTheme()
            XCTAssertEqual(model.themeMode, .fixed)
            let bg = Theme.materialBackground(model.backgroundMaterial)
            XCTAssertGreaterThanOrEqual(Theme.contrast(model.accent, bg), 3.0)
        }
    }

    @MainActor
    func testAccentBecomesContrastSafeWhenMaterialChanges() {
        let model = NotchModel(backend: FakeBackend())
        model.themeMode = .fixed
        model.fixedColorIndex = 2  // Amber
        model.backgroundMaterial = .lightGlass
        let bg = Theme.materialBackground(.lightGlass)
        XCTAssertGreaterThanOrEqual(Theme.contrast(model.accent, bg), 3.0)
    }

    @MainActor
    func testModuleSwitchDirectionTracked() {
        let model = NotchModel(backend: FakeBackend())
        model.switchModule(1)
        XCTAssertTrue(model.moduleSwitchForward)   // forward
        model.switchModule(-1)
        XCTAssertFalse(model.moduleSwitchForward)  // backward
        // dock click: dashboard(0) → dev(3) is forward; → capture(1) back is not
        model.selectModule(.agents)
        XCTAssertTrue(model.moduleSwitchForward)
        model.selectModule(.capture)
        XCTAssertFalse(model.moduleSwitchForward)
    }

    @MainActor
    func testEnteringDevResetsSubSection() {
        let model = NotchModel(backend: FakeBackend())
        model.agentPage = .prs
        model.selectModule(.agents)
        XCTAssertEqual(model.agentPage, .sessions)
    }

    @MainActor
    func testSelectDevTracksDirection() {
        let model = NotchModel(backend: FakeBackend())
        model.agentPage = .sessions
        model.selectAgentPage(.prs)  // forward (down)
        XCTAssertTrue(model.agentPageForward)
        XCTAssertEqual(model.agentPage, .prs)
        model.selectAgentPage(.sessions)  // backward (up)
        XCTAssertFalse(model.agentPageForward)
        model.agentPage = .ports
        model.switchAgentPage(1)
        XCTAssertTrue(model.agentPageForward)
    }

    @MainActor
    func testSwitchDevClampsAtEnds() {
        let model = NotchModel(backend: FakeBackend())
        model.agentPage = .sessions
        model.switchAgentPage(-1)  // already at top
        XCTAssertEqual(model.agentPage, .sessions)  // clamped, no wrap
        model.agentPage = .prs
        model.switchAgentPage(1)  // already at bottom
        XCTAssertEqual(model.agentPage, .prs)  // clamped, no wrap
    }

    @MainActor
    func testSwitchDevPagesThrough() {
        let model = NotchModel(backend: FakeBackend())
        model.agentPage = .sessions
        model.switchAgentPage(1)
        XCTAssertEqual(model.agentPage, .ports)
        model.switchAgentPage(1)
        XCTAssertEqual(model.agentPage, .prs)
    }

    @MainActor
    func testMediaSourceCyclesAndWraps() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.mediaSource, .system)
        model.cycleMediaSource()
        XCTAssertEqual(model.mediaSource, .appleMusic)
        model.cycleMediaSource()  // spotify
        model.cycleMediaSource()  // browser
        XCTAssertEqual(model.mediaSource, .browser)
        model.cycleMediaSource()  // wraps
        XCTAssertEqual(model.mediaSource, .system)
    }

    @MainActor
    func testCalendarDefaultsToMonthViewOnToday() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertTrue(model.calMonthView)
        XCTAssertEqual(model.calMonthOffset, 0)
        XCTAssertEqual(model.calSelectedDay, Calendar.current.component(.day, from: Date()))
    }

    @MainActor
    func testCalendarNavAndToday() {
        let model = NotchModel(backend: FakeBackend())
        model.calNextMonth(); model.calNextMonth()
        XCTAssertEqual(model.calMonthOffset, 2)
        model.calPrevMonth()
        XCTAssertEqual(model.calMonthOffset, 1)
        model.calToday()
        XCTAssertEqual(model.calMonthOffset, 0)
    }

    @MainActor
    func testCalendarViewToggleAndSelect() {
        let model = NotchModel(backend: FakeBackend())
        model.calSetMonthView(false)
        XCTAssertFalse(model.calMonthView)
        model.calSelectDay(15)
        XCTAssertEqual(model.calSelectedDay, 15)
    }

    @MainActor
    func testViewHeightVariesPerModule() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .dashboard
        XCTAssertEqual(model.viewHeight(), 280)
        model.module = .media
        XCTAssertEqual(model.viewHeight(), 300)
        model.module = .files
        XCTAssertEqual(model.viewHeight(), 280)
    }

    @MainActor
    func testViewHeightFollowsDevSection() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .agents
        model.agentPage = .sessions
        XCTAssertEqual(model.viewHeight(), 260)
        model.agentPage = .prs
        XCTAssertEqual(model.viewHeight(), 300)
    }

    @MainActor
    func testViewHeightFollowsCalAndCaptureState() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .calendar
        // NOMI:日历单一预算(月视图随稿退役,calMonthView 不再影响高度)
        model.calMonthView = true
        XCTAssertEqual(model.viewHeight(), 260)
        model.calMonthView = false
        XCTAssertEqual(model.viewHeight(), 260)
        model.module = .capture
        model.captureKind = .journal  // 今天卡+续写按钮(无输入行,预算收)
        XCTAssertEqual(model.viewHeight(), 206)
        model.openJournalEditor()     // 续写弹层编辑:给编辑器足够高(保存行不被 dock 切)
        XCTAssertEqual(model.viewHeight(), 348)
        model.cancelJournalEditor()
        model.captureKind = .note
        XCTAssertEqual(model.viewHeight(), 232)
    }

    @MainActor
    func testAutoExpandedHeightAddsTopBar() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .dashboard
        XCTAssertEqual(model.autoExpandedHeight, 280 + NotchModel.topBarHeight)
    }

    @MainActor
    func testLeavingCaptureClearsLock() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .capture
        model.beginCapture()          // locks for keyboard input
        XCTAssertTrue(model.locked)
        model.selectModule(.media)    // switch away
        XCTAssertFalse(model.locked)  // lock cleared → hover-away can collapse
    }

    @MainActor
    func testCycleCaptureKindWrapsBothWays() {
        let model = NotchModel(backend: FakeBackend())
        model.captureKind = .note
        model.cycleCaptureKind()
        XCTAssertEqual(model.captureKind, .journal)
        model.captureKind = .ask
        model.cycleCaptureKind()
        XCTAssertEqual(model.captureKind, .note)   // wraps forward
        model.cycleCaptureKind(-1)
        XCTAssertEqual(model.captureKind, .ask)    // wraps back
    }

    @MainActor
    func testCaptureRecentsExpandGrowsHeight() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .capture
        model.captureKind = .note
        XCTAssertEqual(model.viewHeight(), 232)
        model.captureShowRecent = true
        XCTAssertEqual(model.viewHeight(), 296)  // 232 + 64
    }

    @MainActor
    func testCaptureMultilineInputGrowsBudgetClamped() {
        // 多行输入:实测超高计入预算;clamp 0...60 防失控。
        let model = NotchModel(backend: FakeBackend())
        model.module = .capture
        model.captureKind = .note
        model.captureInputExtraHeight = 36  // 两行额外
        XCTAssertEqual(model.viewHeight(), 268)  // 232 + 36
        model.captureInputExtraHeight = 999
        XCTAssertEqual(model.viewHeight(), 292)  // clamp 到 +60
        model.captureInputExtraHeight = -5
        XCTAssertEqual(model.viewHeight(), 232)  // clamp 到 0
    }




    @MainActor
    func testFocusStartSeedsWhatAndStopRoundsMinutes() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.focusElapsed(), 0)  // not focusing
        model.captureText = "写 PRD"
        model.startFocus()
        XCTAssertTrue(model.focusOn)
        XCTAssertEqual(model.focusWhat, "写 PRD")
        XCTAssertEqual(model.captureText, "")  // consumed
        XCTAssertEqual(model.focusElapsed(at: model.focusStartedAt.addingTimeInterval(150)), 150)
        let minutes = model.stopFocus(at: model.focusStartedAt.addingTimeInterval(150))
        XCTAssertEqual(minutes, 3)  // 150s → 2.5 → rounds to 3 min, min 1
        XCTAssertFalse(model.focusOn)
    }

    @MainActor
    func testFocusDefaultsWhatWhenTextEmpty() {
        // 番茄制:任务名可留空(视图显示「未设置」),落库时才兜底成「专注」。
        let model = NotchModel(backend: FakeBackend())
        model.captureText = "   "
        model.startFocus()
        XCTAssertEqual(model.focusWhat, "")
        XCTAssertTrue(model.focusOn)
    }

    @MainActor
    func testFocusViewHeight() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .capture
        model.captureKind = .focus
        XCTAssertEqual(model.viewHeight(), 240)  // 番茄环单一预算
        model.captureText = "x"
        model.startFocus()
        XCTAssertEqual(model.viewHeight(), 240)  // 跑与不跑同高
    }

    @MainActor
    func testAskQueriesBrainAndShowsAnswer() async {
        // 2026-07-03 语义:ask = 真问大脑(/api/ask),显示答案,不落 note。
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureKind = .ask
        model.captureText = "Helm 怎么配后端?"
        await model.submit()
        XCTAssertEqual(backend.asked, ["Helm 怎么配后端?"])
        XCTAssertEqual(model.askAnswer, "答:Helm 怎么配后端?")
        XCTAssertTrue(backend.notes.isEmpty)
        XCTAssertEqual(model.captureStatus, .sent)
    }

    @MainActor
    func testAddFilesStagesAndSwitchesToFiles() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .dashboard
        model.captureKind = .focus
        model.addFiles(["report.pdf", "photo.PNG"])
        XCTAssertEqual(model.captureFiles.count, 2)
        XCTAssertEqual(model.captureFiles[0].ext, "PDF")
        XCTAssertEqual(model.captureFiles[1].ext, "PNG")
        XCTAssertEqual(model.module, .files)  // NOMI:拖拽进 shelf
        XCTAssertTrue(model.expanded)
    }

    @MainActor
    func testRemoveFileAndSubmitClears() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.addFiles(["a.txt", "b.txt"])
        let firstID = model.captureFiles[0].id
        model.removeFile(firstID)
        XCTAssertEqual(model.captureFiles.count, 1)
        model.captureText = "归档这个"
        await model.submit()
        XCTAssertTrue(model.captureFiles.isEmpty)  // cleared on submit
    }

    func testReminderStartMinutesParsing() {
        XCTAssertEqual(NotchModel.startMinutes("10:00"), 600)
        XCTAssertEqual(NotchModel.startMinutes("10:00–10:30"), 600)
        XCTAssertNil(NotchModel.startMinutes("全天"))
        XCTAssertNil(NotchModel.startMinutes(""))
    }

    @MainActor
    func testReminderFiresForImminentEvent() async {
        let backend = FakeBackend()
        backend.events = [CalEvent(id: "e1", summary: "Team standup", when: "10:03–10:30")]
        let model = NotchModel(backend: backend)
        await model.refreshEvents()
        let now = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        model.checkReminders(now: now)
        XCTAssertEqual(model.reminder?.id, "e1")
        XCTAssertEqual(model.reminder?.title, "Team standup")
    }

    @MainActor
    func testReminderDoesNotFireForFarEvent() async {
        let backend = FakeBackend()
        backend.events = [CalEvent(id: "e1", summary: "Later", when: "10:30")]
        let model = NotchModel(backend: backend)
        await model.refreshEvents()
        let now = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        model.checkReminders(now: now)
        XCTAssertNil(model.reminder)
    }

    @MainActor
    func testDismissedReminderDoesNotRefire() async {
        let backend = FakeBackend()
        backend.events = [CalEvent(id: "e1", summary: "Standup", when: "10:03")]
        let model = NotchModel(backend: backend)
        await model.refreshEvents()
        let now = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!
        model.checkReminders(now: now)
        XCTAssertNotNil(model.reminder)
        model.dismissReminder()
        XCTAssertNil(model.reminder)
        model.checkReminders(now: now)
        XCTAssertNil(model.reminder)  // dismissed → no re-fire
    }
}

final class CaptureTests: XCTestCase {
    @MainActor
    func testNoteCapturePostsNote() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureKind = .note
        model.captureText = "  随手记一笔  "
        await model.submit()
        XCTAssertEqual(backend.notes.count, 1)
        XCTAssertEqual(backend.notes[0].content, "随手记一笔")  // trimmed
        XCTAssertEqual(backend.notes[0].kind, "note")
        XCTAssertNil(backend.notes[0].journalDate)
        XCTAssertEqual(model.captureStatus, .sent)
        XCTAssertEqual(model.captureText, "")  // cleared on success
    }

    @MainActor
    func testJournalCaptureHasDate() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureKind = .journal
        model.captureText = "今天上线了 m2"
        await model.submit()
        XCTAssertEqual(backend.notes.count, 1)
        XCTAssertEqual(backend.notes[0].kind, "journal")
        XCTAssertNotNil(backend.notes[0].journalDate)
    }


    @MainActor
    func testEmptyCaptureIsNoOp() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureText = "   "
        await model.submit()
        XCTAssertTrue(backend.notes.isEmpty && backend.tasks.isEmpty)
        XCTAssertEqual(model.captureStatus, .idle)
    }

    @MainActor
    func testFailedCaptureKeepsTextAndMarksFailed() async {
        let backend = FakeBackend()
        backend.shouldFailCapture = true
        let model = NotchModel(backend: backend)
        model.captureText = "会失败的"
        await model.submit()
        XCTAssertEqual(model.captureStatus, .failed)
        XCTAssertEqual(model.captureText, "会失败的")  // preserved so the user can retry
    }
}

final class AgentMonitorTests: XCTestCase {
    @MainActor
    func testRefreshAgentsPopulatesAndCounts() async {
        let backend = FakeBackend()
        backend.runs = [
            AgentRun(id: 1, agent: "claude-code", status: "running", prompt: "fix bug"),
            AgentRun(id: 2, agent: "claude-code", status: "waiting_permission", prompt: "rm file"),
            AgentRun(id: 3, agent: "claude-code", status: "completed", prompt: "done"),
        ]
        let model = NotchModel(backend: backend)
        await model.refreshAgents()
        XCTAssertEqual(model.agents.count, 3)
        XCTAssertEqual(model.activeAgentCount, 2)  // running + waiting
        XCTAssertEqual(model.attentionCount, 1)    // waiting_permission only
    }

    @MainActor
    func testRefreshAgentsKeepsLastListOnError() async {
        let backend = FakeBackend()
        backend.runs = [AgentRun(id: 1, agent: "claude-code", status: "running", prompt: "x")]
        let model = NotchModel(backend: backend)
        await model.refreshAgents()
        backend.healthResult = .failure(StubError())  // unrelated; listRuns still returns []
        backend.runs = []
        await model.refreshAgents()
        XCTAssertEqual(model.agents.count, 0)  // listRuns succeeded with empty
    }

    func testAgentRunStatusHelpers() {
        XCTAssertTrue(AgentRun(id: 1, agent: "a", status: "running", prompt: nil).isActive)
        let waiting = AgentRun(id: 2, agent: "a", status: "waiting_permission", prompt: nil)
        XCTAssertTrue(waiting.isActive && waiting.needsAttention)
        XCTAssertFalse(AgentRun(id: 3, agent: "a", status: "completed", prompt: nil).isActive)
    }

    func testDecodesRunsIgnoringExtraFields() throws {
        let json = #"{"runs":[{"id":7,"session_id":"s","project_path":"/p","agent":"claude-code","status":"running","prompt":"hi","error":null,"started_at":null,"ended_at":null}]}"#.data(using: .utf8)!
        struct Resp: Decodable { let runs: [AgentRun] }
        let runs = try JSONDecoder().decode(Resp.self, from: json).runs
        XCTAssertEqual(runs, [AgentRun(id: 7, agent: "claude-code", status: "running", prompt: "hi")])
    }
}

final class MediaTests: XCTestCase {
    @MainActor
    func testRefreshMediaPopulatesNowPlaying() async {
        let media = FakeMedia(current: NowPlaying(title: "夜曲", artist: "周杰伦", isPlaying: true))
        let model = NotchModel(backend: FakeBackend(), media: media)
        await model.refreshMedia()
        XCTAssertEqual(model.nowPlaying?.title, "夜曲")
        XCTAssertEqual(model.nowPlaying?.artist, "周杰伦")
        XCTAssertTrue(model.nowPlaying?.isPlaying ?? false)
    }

    @MainActor
    func testNilWhenNothingPlaying() async {
        let model = NotchModel(backend: FakeBackend(), media: FakeMedia(current: nil))
        await model.refreshMedia()
        XCTAssertNil(model.nowPlaying)
    }

    @MainActor
    func testTransportCommandsForward() {
        let media = FakeMedia()
        let model = NotchModel(backend: FakeBackend(), media: media)
        model.playPause()
        model.nextTrack()
        model.previousTrack()
        XCTAssertEqual(media.commands, ["playPause", "next", "prev"])
    }

    @MainActor
    func testDefaultsToNoMedia() async {
        let model = NotchModel(backend: FakeBackend())  // no media arg
        await model.refreshMedia()
        XCTAssertNil(model.nowPlaying)
    }
}

final class ConfigAndExpansionTests: XCTestCase {
    func testBaseURLFromEnvOverride() {
        let url = HelmClient.baseURL(from: ["HELM_NOTCH_URL": "http://192.168.1.5:9000"])
        XCTAssertEqual(url.absoluteString, "http://192.168.1.5:9000")
    }

    func testBaseURLDefaultsWhenUnsetOrEmpty() {
        XCTAssertEqual(HelmClient.baseURL(from: [:]).absoluteString, "http://127.0.0.1:8769")
        XCTAssertEqual(HelmClient.baseURL(from: ["HELM_NOTCH_URL": ""]).absoluteString, "http://127.0.0.1:8769")
    }

    @MainActor
    func testCollapseResetsState() {
        let model = NotchModel(backend: FakeBackend())
        model.toggleExpanded()
        XCTAssertTrue(model.expanded)
        model.collapse()
        XCTAssertFalse(model.expanded)
    }
}

final class HealthDecodingTests: XCTestCase {
    func testDecodesHealthz() throws {
        let json = #"{"status":"ok","version":"0.0.1"}"#.data(using: .utf8)!
        let health = try JSONDecoder().decode(Health.self, from: json)
        XCTAssertEqual(health, Health(status: "ok", version: "0.0.1"))
    }
    @MainActor
    func testClipboardHistoryDedupesAndCaps() {
        let model = NotchModel(backend: FakeBackend())
        model.recordClipboard("aaa")
        model.recordClipboard("aaa")  // 连续重复不重记
        XCTAssertEqual(model.clipboardHistory.count, 1)
        for i in 0..<6 { model.recordClipboard("item\(i)") }
        XCTAssertEqual(model.clipboardHistory.count, 5)  // 上限 5
        XCTAssertEqual(model.clipboardHistory.first?.text, "item5")  // 新的在前
        XCTAssertTrue(ClipItem(id: "x", text: "https://a.b", at: Date()).isLink)
    }

    @MainActor
    func testPomodoroPauseBanksAndResumes() {
        let model = NotchModel(backend: FakeBackend())
        model.startFocus()
        let t0 = model.focusStartedAt
        model.pauseFocus(at: t0.addingTimeInterval(300))  // 跑 5 分钟暂停
        XCTAssertFalse(model.focusOn)
        XCTAssertEqual(model.focusBanked, 300)
        XCTAssertEqual(model.focusRemaining(), 25 * 60 - 300)
        model.startFocus()  // 继续
        let t1 = model.focusStartedAt
        XCTAssertEqual(model.focusElapsed(at: t1.addingTimeInterval(60)), 360)
        model.resetFocus()
        XCTAssertEqual(model.focusRemaining(), 25 * 60)
    }

    @MainActor
    func testJournalTodayJoinsServerFilteredEntries() async {
        // T5 契约:journal_date 由服务端过滤,notch 只按返回顺序拼接。
        let backend = FakeBackend()
        backend.journals = [
            RecentNote(id: 2, content: "早上开工", kind: "journal", createdAt: "09:00"),
            RecentNote(id: 3, content: "晚上收尾", kind: "journal", createdAt: "22:10"),
        ]
        let model = NotchModel(backend: backend)
        await model.loadJournalToday()
        XCTAssertEqual(model.journalToday, "早上开工\n\n晚上收尾")
        backend.journals = []
        await model.loadJournalToday()
        XCTAssertNil(model.journalToday)  // 空日诚实为 nil(显示「还没动笔」)
    }

}
