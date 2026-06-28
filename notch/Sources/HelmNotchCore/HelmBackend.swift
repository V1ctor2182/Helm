import Foundation

/// The slice of the Helm backend the notch needs. A protocol so the app talks
/// to a real `HelmClient` while tests inject a fake (no network) — the same
/// injectable-interface pattern the Helm Python backend uses throughout.
public protocol HelmBackend: Sendable {
    func health() async throws -> Health
    /// Quick-capture a note (kind "note" = 速记, "journal" = 日记). `journalDate`
    /// is the ISO `yyyy-MM-dd` day for journal entries (nil for notes).
    func createNote(content: String, kind: String, journalDate: String?) async throws
    /// Create a scheduled task from a prompt (default daily schedule).
    func createTask(prompt: String) async throws
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

    public func createNote(content: String, kind: String, journalDate: String?) async throws {
        struct Body: Encodable {
            let content: String
            let kind: String
            let journal_date: String?
        }
        try await post("api/notes", Body(content: content, kind: kind, journal_date: journalDate))
    }

    public func createTask(prompt: String) async throws {
        struct Body: Encodable {
            let name: String
            let prompt: String
            let schedule_kind: String
            let schedule_value: [String: String]
        }
        let name = String(prompt.prefix(40))
        // Default to a daily 9am cron — matches the web Journal's task default.
        try await post(
            "api/tasks",
            Body(name: name, prompt: prompt, schedule_kind: "cron", schedule_value: ["expr": "0 9 * * *"])
        )
    }

    private func post<T: Encodable>(_ path: String, _ body: T) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HelmError.badStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}
