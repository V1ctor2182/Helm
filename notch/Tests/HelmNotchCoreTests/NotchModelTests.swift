import XCTest

@testable import HelmNotchCore

/// A fake backend so the core is tested with no real network. Records capture
/// calls for assertions (`@unchecked Sendable` — accessed only from the test's
/// MainActor, sequentially via `await`).
final class FakeBackend: HelmBackend, @unchecked Sendable {
    var healthResult: Result<Health, Error>
    var shouldFailCapture = false
    private(set) var notes: [(content: String, kind: String, journalDate: String?)] = []
    private(set) var tasks: [String] = []

    init(healthResult: Result<Health, Error> = .success(Health(status: "ok", version: "0.0.1"))) {
        self.healthResult = healthResult
    }

    func health() async throws -> Health {
        try healthResult.get()
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

final class HealthDecodingTests: XCTestCase {
    func testDecodesHealthz() throws {
        let json = #"{"status":"ok","version":"0.0.1"}"#.data(using: .utf8)!
        let health = try JSONDecoder().decode(Health.self, from: json)
        XCTAssertEqual(health, Health(status: "ok", version: "0.0.1"))
    }
}
