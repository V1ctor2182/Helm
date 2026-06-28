import XCTest

@testable import HelmNotchCore

/// A fake backend so the core is tested with no real network.
struct FakeBackend: HelmBackend {
    let result: Result<Health, Error>
    func health() async throws -> Health {
        try result.get()
    }
}

struct StubError: Error {}

final class NotchModelTests: XCTestCase {
    @MainActor
    func testConnectsOnHealthyBackend() async {
        let model = NotchModel(
            backend: FakeBackend(result: .success(Health(status: "ok", version: "0.0.1")))
        )
        await model.refresh()
        XCTAssertEqual(model.connection, .connected(version: "0.0.1"))
    }

    @MainActor
    func testDisconnectsWhenBackendErrors() async {
        let model = NotchModel(backend: FakeBackend(result: .failure(StubError())))
        await model.refresh()
        XCTAssertEqual(model.connection, .disconnected)
    }

    @MainActor
    func testStartsUnknown() {
        let model = NotchModel(
            backend: FakeBackend(result: .success(Health(status: "ok", version: "1")))
        )
        XCTAssertEqual(model.connection, .unknown)
    }
}

final class HealthDecodingTests: XCTestCase {
    func testDecodesHealthz() throws {
        let json = #"{"status":"ok","version":"0.0.1"}"#.data(using: .utf8)!
        let health = try JSONDecoder().decode(Health.self, from: json)
        XCTAssertEqual(health, Health(status: "ok", version: "0.0.1"))
    }
}
