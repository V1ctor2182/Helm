import Foundation

/// `/healthz` payload from the Helm backend.
public struct Health: Codable, Sendable, Equatable {
    public let status: String
    public let version: String

    public init(status: String, version: String) {
        self.status = status
        self.version = version
    }
}

/// Connection state to the Helm backend, surfaced as the notch status dot.
public enum ConnectionState: Sendable, Equatable {
    case unknown
    case connected(version: String)
    case disconnected
}
