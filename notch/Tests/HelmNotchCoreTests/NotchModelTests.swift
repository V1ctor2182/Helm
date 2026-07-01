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

    func listEvents(start: Date, end: Date) async throws -> [CalEvent] {
        events
    }

    func createNote(content: String, kind: String, journalDate: String?) async throws {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        notes.append((content, kind, journalDate))
    }

    func createTask(prompt: String) async throws {
        if shouldFailCapture { throw HelmError.badStatus(500) }
        tasks.append(prompt)
    }
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
}

/// Module/dock state machine ported from helm-notch-pro.html.
final class NotchModuleTests: XCTestCase {
    @MainActor
    func testStartsOnDashboard() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.module, .dashboard)
        XCTAssertEqual(model.devSection, .agents)
    }

    @MainActor
    func testDockOrderExcludesMedia() {
        XCTAssertEqual(NotchModule.dock, [.dashboard, .capture, .calendar, .dev, .clipboard])
        XCTAssertFalse(NotchModule.dock.contains(.media))
    }

    @MainActor
    func testSwitchModuleWrapsForward() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .clipboard  // last in the dock
        model.switchModule(1)
        XCTAssertEqual(model.module, .dashboard)  // wraps to first
    }

    @MainActor
    func testSwitchModuleWrapsBackward() {
        let model = NotchModel(backend: FakeBackend())
        model.switchModule(-1)  // from dashboard (first)
        XCTAssertEqual(model.module, .clipboard)  // wraps to last
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
        model.selectModule(.dev)
        XCTAssertTrue(model.moduleSwitchForward)
        model.selectModule(.capture)
        XCTAssertFalse(model.moduleSwitchForward)
    }

    @MainActor
    func testEnteringDevResetsSubSection() {
        let model = NotchModel(backend: FakeBackend())
        model.devSection = .stats
        model.selectModule(.dev)
        XCTAssertEqual(model.devSection, .agents)
    }

    @MainActor
    func testSelectDevTracksDirection() {
        let model = NotchModel(backend: FakeBackend())
        model.devSection = .agents
        model.selectDev(.stats)  // forward (down)
        XCTAssertTrue(model.devSwitchForward)
        XCTAssertEqual(model.devSection, .stats)
        model.selectDev(.agents)  // backward (up)
        XCTAssertFalse(model.devSwitchForward)
        model.devSection = .ports
        model.switchDev(1)
        XCTAssertTrue(model.devSwitchForward)
    }

    @MainActor
    func testSwitchDevClampsAtEnds() {
        let model = NotchModel(backend: FakeBackend())
        model.devSection = .agents
        model.switchDev(-1)  // already at top
        XCTAssertEqual(model.devSection, .agents)  // clamped, no wrap
        model.devSection = .stats
        model.switchDev(1)  // already at bottom
        XCTAssertEqual(model.devSection, .stats)  // clamped, no wrap
    }

    @MainActor
    func testSwitchDevPagesThrough() {
        let model = NotchModel(backend: FakeBackend())
        model.devSection = .agents
        model.switchDev(1)
        XCTAssertEqual(model.devSection, .ports)
        model.switchDev(1)
        XCTAssertEqual(model.devSection, .reviews)
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
        XCTAssertEqual(model.viewHeight(), 172)
        model.module = .media
        XCTAssertEqual(model.viewHeight(), 330)
        model.module = .clipboard
        XCTAssertEqual(model.viewHeight(), 232)
    }

    @MainActor
    func testViewHeightFollowsDevSection() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .dev
        model.devSection = .agents
        XCTAssertEqual(model.viewHeight(), 204)
        model.devSection = .stats
        XCTAssertEqual(model.viewHeight(), 252)
    }

    @MainActor
    func testViewHeightFollowsCalAndCaptureState() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .calendar
        model.calMonthView = true
        XCTAssertEqual(model.viewHeight(), 312)
        model.calMonthView = false
        XCTAssertEqual(model.viewHeight(), 240)
        model.module = .capture
        model.captureKind = .task
        XCTAssertEqual(model.viewHeight(), 258)
        model.captureKind = .note
        XCTAssertEqual(model.viewHeight(), 214)
    }

    @MainActor
    func testAutoExpandedHeightAddsTopBar() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .dashboard
        XCTAssertEqual(model.autoExpandedHeight, 172 + NotchModel.topBarHeight)
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
        XCTAssertEqual(model.viewHeight(), 214)
        model.captureShowRecent = true
        XCTAssertEqual(model.viewHeight(), 278)  // 214 + 64
    }

    @MainActor
    func testTaskTargetDefaultsToMe() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertEqual(model.taskTarget, .me)
    }

    @MainActor
    func testCaptureFoldsTimeAndPlaceAndResets() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureKind = .note
        model.captureText = "买牛奶"
        model.captureWhen = "今天 15:00"
        model.captureWhere = "Brooklyn"
        await model.submit()
        XCTAssertEqual(backend.notes.count, 1)
        XCTAssertEqual(backend.notes[0].content, "买牛奶 · 今天 15:00 · Brooklyn")
        XCTAssertNil(model.captureWhen)
        XCTAssertNil(model.captureWhere)
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
        let model = NotchModel(backend: FakeBackend())
        model.captureText = "   "
        model.startFocus()
        XCTAssertEqual(model.focusWhat, "专注")
    }

    @MainActor
    func testFocusViewHeight() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .capture
        model.captureKind = .focus
        XCTAssertEqual(model.viewHeight(), 240)  // idle
        model.captureText = "x"
        model.startFocus()
        XCTAssertEqual(model.viewHeight(), 300)  // running
    }

    @MainActor
    func testAskPostsAsAskNote() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureKind = .ask
        model.captureText = "Helm 怎么配后端?"
        await model.submit()
        XCTAssertEqual(backend.notes.count, 1)
        XCTAssertEqual(backend.notes[0].kind, "ask")
        XCTAssertEqual(model.captureStatus, .sent)
    }

    @MainActor
    func testAddFilesStagesAndSwitchesToCapture() {
        let model = NotchModel(backend: FakeBackend())
        model.module = .dashboard
        model.captureKind = .focus
        model.addFiles(["report.pdf", "photo.PNG"])
        XCTAssertEqual(model.captureFiles.count, 2)
        XCTAssertEqual(model.captureFiles[0].ext, "PDF")
        XCTAssertEqual(model.captureFiles[1].ext, "PNG")
        XCTAssertEqual(model.module, .capture)
        XCTAssertEqual(model.captureKind, .note)  // focus → note when files dropped
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
    func testTaskCapturePostsTask() async {
        let backend = FakeBackend()
        let model = NotchModel(backend: backend)
        model.captureKind = .task
        model.captureText = "汇总今日进展"
        await model.submit()
        XCTAssertEqual(backend.tasks, ["汇总今日进展"])
        XCTAssertTrue(backend.notes.isEmpty)
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
}
