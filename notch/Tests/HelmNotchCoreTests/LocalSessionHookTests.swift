import XCTest

@testable import HelmNotchCore

/// 本机 Claude Code 监听:hook 事件状态机 + 选择题解析/答案合并。
final class LocalSessionHookTests: XCTestCase {
    private let askInput = """
        {"questions":[{"question":"用哪个方案?","header":"方案",\
        "multiSelect":false,"options":[{"label":"方案 A","description":"稳"},\
        {"label":"方案 B","description":"快"}]}]}
        """

    @MainActor private func makeModel() -> NotchModel { NotchModel(backend: FakeBackend()) }

    // MARK: QuestionPrompt

    func testParseAskUserQuestionInput() throws {
        let q = try XCTUnwrap(QuestionPrompt.parse(toolInputJSON: askInput))
        XCTAssertEqual(q.items.count, 1)
        let item = q.items[0]
        XCTAssertEqual(item.question, "用哪个方案?")
        XCTAssertEqual(item.header, "方案")
        XCTAssertFalse(item.multiSelect)
        // 两个原始选项 + 镜像的"其他"自由输入项
        XCTAssertEqual(item.options.count, 3)
        XCTAssertEqual(item.options[0].label, "方案 A")
        XCTAssertTrue(item.options[2].allowsFreeform)
    }

    func testParseRejectsNonQuestionInput() {
        XCTAssertNil(QuestionPrompt.parse(toolInputJSON: #"{"command":"ls"}"#))
        XCTAssertNil(QuestionPrompt.parse(toolInputJSON: "not json"))
        XCTAssertNil(QuestionPrompt.parse(toolInputJSON: #"{"questions":[]}"#))
    }

    func testMergeAnswersIntoToolInput() throws {
        let merged = try XCTUnwrap(
            QuestionPrompt.mergeAnswers(["用哪个方案?": "方案 A"], intoToolInputJSON: askInput))
        let obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(merged.utf8)) as? [String: Any])
        XCTAssertEqual(obj["answers"] as? [String: String], ["用哪个方案?": "方案 A"])
        XCTAssertNotNil(obj["questions"])  // 原字段保留
    }

    // MARK: applyHook 状态机

    @MainActor
    func testQuestionRequestEntersWaitingQuestion() {
        let model = makeModel()
        model.applyHook(HookMessage(
            event: "PermissionRequest", session: "s1", cwd: "/w/helm",
            tool: "AskUserQuestion", detail: "用哪个方案?", reply: true, toolInput: askInput))
        let s = model.localSessions[0]
        XCTAssertEqual(s.phase, .waitingQuestion)
        XCTAssertNotNil(s.question)
        XCTAssertTrue(s.needsAttention)
    }

    @MainActor
    func testUnparseableQuestionFallsBackToPermission() {
        let model = makeModel()
        model.applyHook(HookMessage(
            event: "PermissionRequest", session: "s1", cwd: "/w",
            tool: "AskUserQuestion", detail: "?", reply: true, toolInput: nil))
        XCTAssertEqual(model.localSessions[0].phase, .waitingPermission)
        XCTAssertNil(model.localSessions[0].question)
    }

    @MainActor
    func testStopGoesIdleAndSessionEndEnds() {
        let model = makeModel()
        model.applyHook(HookMessage(event: "SessionStart", session: "s1", cwd: "/w"))
        model.applyHook(HookMessage(event: "Stop", session: "s1", assistant: "改完了"))
        XCTAssertEqual(model.localSessions[0].phase, .idle)
        XCTAssertEqual(model.localSessions[0].lastAssistant, "改完了")
        XCTAssertFalse(model.localSessions[0].isActive)
        model.applyHook(HookMessage(event: "SessionEnd", session: "s1"))
        XCTAssertEqual(model.localSessions[0].phase, .ended)
    }

    @MainActor
    func testSubagentStopDoesNotEndSession() {
        let model = makeModel()
        model.applyHook(HookMessage(event: "UserPromptSubmit", session: "s1", prompt: "修 bug"))
        model.applyHook(HookMessage(event: "SubagentStop", session: "s1"))
        XCTAssertEqual(model.localSessions[0].phase, .running)
        XCTAssertEqual(model.localSessions[0].lastPrompt, "修 bug")
    }

    @MainActor
    func testResolveQuestionSendsMergedUpdatedInput() throws {
        let model = makeModel()
        var got: (session: String, allow: Bool, updated: String?)?
        model.resolvePermission = { got = ($0, $1, $2) }
        model.applyHook(HookMessage(
            event: "PermissionRequest", session: "s1", cwd: "/w",
            tool: "AskUserQuestion", detail: "?", reply: true, toolInput: askInput))
        model.resolveLocalQuestion("s1", answers: ["用哪个方案?": "方案 B"])

        let result = try XCTUnwrap(got)
        XCTAssertEqual(result.session, "s1")
        XCTAssertTrue(result.allow)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(
            with: Data(XCTUnwrap(result.updated).utf8)) as? [String: Any])
        XCTAssertEqual(obj["answers"] as? [String: String], ["用哪个方案?": "方案 B"])
        // 会话回到 running,待办清空
        XCTAssertEqual(model.localSessions[0].phase, .running)
        XCTAssertNil(model.localSessions[0].question)
    }

    @MainActor
    func testNotificationDoesNotDemoteParkedQuestion() {
        // PermissionRequest 静候期间 Claude 会发 "needs your permission" 的
        // Notification;不挡住它,横幅会闪现即消(2026-07-06 用户实测)。
        let model = makeModel()
        model.applyHook(HookMessage(
            event: "PermissionRequest", session: "s1", cwd: "/w",
            tool: "AskUserQuestion", detail: "?", reply: true, toolInput: askInput))
        model.applyHook(HookMessage(event: "Notification", session: "s1", detail: "needs permission"))
        XCTAssertEqual(model.localSessions[0].phase, .waitingQuestion)
        XCTAssertNotNil(model.localSessions[0].question)
        // 普通权限同样受保护
        model.applyHook(HookMessage(
            event: "PermissionRequest", session: "s2", cwd: "/w",
            tool: "Bash", detail: "rm -rf x", reply: true))
        model.applyHook(HookMessage(event: "PreToolUse", session: "s2", tool: "Bash"))
        XCTAssertEqual(model.localSessions.first { $0.id == "s2" }?.phase, .waitingPermission)
    }

    @MainActor
    func testHookDroppedRetractsBanner() {
        // 用户在终端作答 → 挂起的 hook 连接断开 → 横幅撤下回 running。
        let model = makeModel()
        model.applyHook(HookMessage(
            event: "PermissionRequest", session: "s1", cwd: "/w",
            tool: "AskUserQuestion", detail: "?", reply: true, toolInput: askInput))
        model.hookDropped("s1")
        XCTAssertEqual(model.localSessions[0].phase, .running)
        XCTAssertNil(model.localSessions[0].question)
        // 非挂起状态的会话不受影响
        model.applyHook(HookMessage(event: "Stop", session: "s1"))
        model.hookDropped("s1")
        XCTAssertEqual(model.localSessions[0].phase, .idle)
    }

    @MainActor
    func testTerminalIdentityRidesAlong() {
        let model = makeModel()
        model.applyHook(HookMessage(
            event: "SessionStart", session: "s1", cwd: "/w",
            term: "ghostty", tmuxPane: "%3", tmuxSocket: "/tmp/tmux-501/default"))
        let s = model.localSessions[0]
        XCTAssertEqual(s.termProgram, "ghostty")
        XCTAssertEqual(s.tmuxPane, "%3")
        XCTAssertEqual(s.tmuxSocket, "/tmp/tmux-501/default")
    }

    @MainActor
    func testSelectionClearsWhenLeavingDevModule() {
        let model = makeModel()
        model.applyHook(HookMessage(event: "SessionStart", session: "s1"))
        model.selectedLocalSessionID = "s1"
        XCTAssertNotNil(model.selectedLocalSession)
        model.selectModule(.dashboard)
        XCTAssertNil(model.selectedLocalSessionID)
    }
}
