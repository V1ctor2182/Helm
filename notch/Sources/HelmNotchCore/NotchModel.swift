import Foundation
import Observation

/// Observable state behind the notch UI. m1 added the backend connection; m2
/// adds quick-capture (速记/日记/任务) straight from the notch into Helm.
@MainActor
@Observable
public final class NotchModel {
    public private(set) var connection: ConnectionState = .unknown

    /// Whether the notch is expanded into the capture form.
    public var expanded = false
    public var captureKind: CaptureKind = .note
    public var captureText = ""
    public private(set) var captureStatus: CaptureStatus = .idle

    /// Agent runs Helm knows about (m3 monitor).
    public private(set) var agents: [AgentRun] = []

    /// Running or blocked agents — surfaced on the collapsed pill.
    public var activeAgentCount: Int { agents.lazy.filter(\.isActive).count }
    /// Agents blocked on a permission decision (needs the user).
    public var attentionCount: Int { agents.lazy.filter(\.needsAttention).count }

    /// Current now-playing media (nil when nothing is playing / unavailable).
    public private(set) var nowPlaying: NowPlaying?

    private let backend: HelmBackend
    private let media: MediaController

    public init(backend: HelmBackend, media: MediaController = NoMediaController()) {
        self.backend = backend
        self.media = media
    }

    /// One poll tick: connection + agent runs + media.
    public func poll() async {
        await refresh()
        await refreshAgents()
        await refreshMedia()
    }

    public func refreshMedia() async {
        nowPlaying = await media.nowPlaying()
    }

    public func playPause() { media.playPause() }
    public func nextTrack() { media.nextTrack() }
    public func previousTrack() { media.previousTrack() }

    /// Poll the backend once and fold the result into `connection`.
    public func refresh() async {
        do {
            let health = try await backend.health()
            connection = .connected(version: health.version)
        } catch {
            connection = .disconnected
        }
    }

    /// Refresh the agent run list; keep the last list on error.
    public func refreshAgents() async {
        if let runs = try? await backend.listRuns() {
            agents = runs
        }
    }

    public func toggleExpanded() {
        expanded.toggle()
        if !expanded { captureStatus = .idle }
    }

    public func collapse() {
        expanded = false
        captureStatus = .idle
    }

    /// Submit the current capture text to Helm via the kind's endpoint.
    public func submit() async {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        captureStatus = .sending
        do {
            switch captureKind {
            case .note:
                try await backend.createNote(content: text, kind: "note", journalDate: nil)
            case .journal:
                try await backend.createNote(content: text, kind: "journal", journalDate: Self.today())
            case .task:
                try await backend.createTask(prompt: text)
            }
            captureText = ""
            captureStatus = .sent
        } catch {
            captureStatus = .failed
        }
    }

    /// Today's date as ISO `yyyy-MM-dd` in the local timezone.
    static func today() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
