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
    /// List the agent runs Helm knows about (for the notch agent monitor).
    func listRuns() async throws -> [AgentRun]
    /// Calendar events in `[start, end)` (for the notch's 日历 cell).
    func listEvents(start: Date, end: Date) async throws -> [CalEvent]
}

public extension HelmBackend {
    /// Default so fakes/tests that don't care about calendar still conform.
    func listEvents(start: Date, end: Date) async throws -> [CalEvent] { [] }
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

    /// Resolve the backend URL from an environment map — `HELM_NOTCH_URL`
    /// overrides the loopback default (e.g. for an SSH-forwarded backend).
    public static func baseURL(from environment: [String: String]) -> URL {
        if let raw = environment["HELM_NOTCH_URL"],
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return URL(string: "http://127.0.0.1:8769")!
    }

    /// The backend URL for this process (reads `HELM_NOTCH_URL`).
    public static func defaultBaseURL() -> URL {
        baseURL(from: ProcessInfo.processInfo.environment)
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

    public func listRuns() async throws -> [AgentRun] {
        struct Response: Decodable { let runs: [AgentRun] }
        let url = baseURL.appendingPathComponent("api/orchestration/runs")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(Response.self, from: data).runs
    }

    public func listEvents(start: Date, end: Date) async throws -> [CalEvent] {
        struct Response: Decodable { let events: [EventDTO] }
        struct EventDTO: Decodable {
            let id: Int
            let uid: String?
            let summary: String
            let start: String?
            let end: String?
            let all_day: Bool
        }
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("api/calendar/events"),
            resolvingAgainstBaseURL: false)!
        let iso = ISO8601DateFormatter()
        comps.queryItems = [
            URLQueryItem(name: "start", value: iso.string(from: start)),
            URLQueryItem(name: "end", value: iso.string(from: end)),
        ]
        let (data, _) = try await session.data(from: comps.url!)
        let resp = try JSONDecoder().decode(Response.self, from: data)
        return resp.events.map {
            CalEvent(
                id: $0.uid ?? String($0.id),
                summary: $0.summary,
                when: Self.eventWhen(allDay: $0.all_day, start: $0.start, end: $0.end))
        }
    }

    /// Short display string for an event time ("全天" / "10:00" / "10:00–10:30").
    static func eventWhen(allDay: Bool, start: String?, end: String?) -> String {
        if allDay { return "全天" }
        guard let s = clockTime(start) else { return "" }
        if let e = clockTime(end) { return "\(s)–\(e)" }
        return s
    }

    /// Pull "HH:mm" out of an ISO timestamp, tolerant of offset / fractional secs.
    private static func clockTime(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let parsers = [ISO8601DateFormatter(), { let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f }()]
        for p in parsers {
            if let d = p.date(from: iso) {
                let f = DateFormatter(); f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_US")
                return f.string(from: d)
            }
        }
        // Fallback: slice "…THH:mm…" out of the raw string.
        if let t = iso.split(separator: "T").dropFirst().first { return String(t.prefix(5)) }
        return nil
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
