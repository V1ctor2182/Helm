import Foundation
import Observation

/// Observable state behind the notch UI. m1: just the backend connection. Later
/// milestones add journal capture, agent sessions, and now-playing media.
@MainActor
@Observable
public final class NotchModel {
    public private(set) var connection: ConnectionState = .unknown

    private let backend: HelmBackend

    public init(backend: HelmBackend) {
        self.backend = backend
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
}
