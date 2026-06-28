import Foundation

/// The slice of the Helm backend the notch needs. A protocol so the app talks
/// to a real `HelmClient` while tests inject a fake (no network) — the same
/// injectable-interface pattern the Helm Python backend uses throughout.
public protocol HelmBackend: Sendable {
    func health() async throws -> Health
}

/// Talks to the local Helm FastAPI backend over HTTP (default loopback:8769).
public struct HelmClient: HelmBackend {
    public let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: "http://127.0.0.1:8769")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func health() async throws -> Health {
        let url = baseURL.appendingPathComponent("healthz")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(Health.self, from: data)
    }
}
