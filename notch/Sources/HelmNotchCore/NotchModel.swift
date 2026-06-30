import Foundation
import Observation

/// Observable state behind the notch UI. m1 added the backend connection; m2
/// adds quick-capture (速记/日记/任务) straight from the notch into Helm.
@MainActor
@Observable
public final class NotchModel {
    public private(set) var connection: ConnectionState = .unknown

    /// Whether the notch is expanded into the 2×2 panel (hover-driven).
    public var expanded = false
    /// Interaction lock: while set, the panel ignores hover-collapse and becomes
    /// key (keyboard). Entered by clicking the capture cell (速记) or answering an
    /// agent. Left on send / Esc / click-away.
    public var locked = false
    public var captureKind: CaptureKind = .note
    public var captureText = ""
    public private(set) var captureStatus: CaptureStatus = .idle

    // MARK: Module switching (dock + view), ported from helm-notch-pro.html

    /// The module shown in the expanded panel (HTML `S.view`).
    public var module: NotchModule = .dashboard
    /// The Dev module's active sub-section (HTML `S.devSec`).
    public var devSection: DevSection = .agents
    /// The player the transport controls (HTML `S.mediaSrc`).
    public private(set) var mediaSource: MediaSource = .system

    /// Cycle to the next media source (HTML `srccycle`), wrapping around.
    public func cycleMediaSource() {
        let all = MediaSource.allCases
        let i = all.firstIndex(of: mediaSource) ?? 0
        mediaSource = all[(i + 1) % all.count]
    }

    /// Select a module directly (HTML dock click). Entering Dev resets to its
    /// first sub-section, matching `if(S.view==='dev')S.devSec=0`.
    public func selectModule(_ m: NotchModule) {
        module = m
        if m == .dev { devSection = .agents }
    }

    /// Cycle the docked modules left/right with wrap-around (HTML
    /// `switchModule(dir)`). `media` is excluded — it is a zoom target only.
    public func switchModule(_ direction: Int) {
        let dock = NotchModule.dock
        let count = dock.count
        let i = dock.firstIndex(of: module) ?? 0
        selectModule(dock[((i + direction) % count + count) % count])
    }

    /// Page the Dev sub-sections vertically (HTML `switchDev(dir)`). Clamps at
    /// the ends — no wrap.
    public func switchDev(_ direction: Int) {
        let all = DevSection.allCases
        guard let i = all.firstIndex(of: devSection) else { return }
        let next = i + direction
        guard next >= 0, next < all.count else { return }
        devSection = all[next]
    }

    // MARK: Theme (daily-rotating accent)

    public var themeMode: ThemeMode = .daily { didSet { refreshTheme() } }
    public var fixedColorIndex = 0 { didSet { refreshTheme() } }
    /// The current accent color (recomputed each poll so it flips at midnight).
    public private(set) var accent: RGB = Theme.accent(for: Date(), mode: .daily)

    // MARK: Panel geometry (user-resizable, persisted by the controller)

    /// Detected physical notch width in points (set by the controller).
    public var notchWidth: Double = 200
    public var expandedWidth: Double = 600
    public var expandedHeight: Double = 268

    /// Agent runs Helm knows about (backend orchestration).
    public private(set) var agents: [AgentRun] = []

    /// Locally-watched Claude Code sessions (hook+bridge). Primary source for the
    /// 本机 agent cell.
    public private(set) var localSessions: [LocalSession] = []

    /// Set by the controller — routes a permission verdict back to the bridge.
    public var resolvePermission: (@MainActor (_ session: String, _ allow: Bool) -> Void)?

    /// Set by the app — opens the settings window (gear button in the panel).
    public var openSettings: (@MainActor () -> Void)?

    public var localActiveCount: Int { localSessions.lazy.filter(\.isActive).count }
    public var localAttentionCount: Int { localSessions.lazy.filter(\.needsAttention).count }

    /// Running or blocked agents — surfaced on the collapsed pill.
    public var activeAgentCount: Int { agents.lazy.filter(\.isActive).count }
    /// Agents blocked on a permission decision (needs the user).
    public var attentionCount: Int { agents.lazy.filter(\.needsAttention).count }

    /// Today's calendar events (m2 — empty until the API is wired).
    public private(set) var events: [CalEvent] = []

    /// Current now-playing media (nil when nothing is playing / unavailable).
    public private(set) var nowPlaying: NowPlaying?
    /// Wall-clock time the current `nowPlaying` snapshot was captured — lets the
    /// UI advance the progress bar smoothly between 5s polls.
    public private(set) var nowPlayingFetchedAt = Date()

    private let backend: HelmBackend
    private let media: MediaController
    private var collapseTask: Task<Void, Never>?

    public init(backend: HelmBackend, media: MediaController = NoMediaController()) {
        self.backend = backend
        self.media = media
    }

    /// One poll tick: connection + agent runs + media + theme (midnight rollover).
    public func poll() async {
        refreshTheme()
        await refresh()
        await refreshAgents()
        await refreshEvents()
        await refreshMedia()
    }

    /// Refresh today's calendar events; keep the last list on error.
    public func refreshEvents() async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        if let evs = try? await backend.listEvents(start: start, end: end) {
            events = evs
        }
    }

    /// Recompute the accent for today under the current mode.
    public func refreshTheme() {
        accent = Theme.accent(for: Date(), mode: themeMode, fixedIndex: fixedColorIndex)
    }

    /// Clamp + apply a user drag-resize of the expanded panel.
    public func resize(width: Double, height: Double) {
        expandedWidth = min(max(width, 480), 1000)
        expandedHeight = min(max(height, 230), 560)
    }

    public func refreshMedia() async {
        let snapshot = await media.nowPlaying()
        nowPlaying = snapshot
        nowPlayingFetchedAt = Date()
    }

    /// Live playback position in seconds, advanced from the last poll while
    /// playing. `now` is passed in so a `TimelineView` can drive it each tick.
    public func livePosition(at now: Date = Date()) -> Double {
        guard let np = nowPlaying, let elapsed = np.elapsed else { return 0 }
        let advanced = np.isPlaying ? now.timeIntervalSince(nowPlayingFetchedAt) : 0
        let position = elapsed + max(0, advanced)
        if let duration = np.duration, duration > 0 { return min(position, duration) }
        return position
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

    // MARK: Local Claude Code monitoring (bridge events)

    /// Fold one hook event into `localSessions`.
    public func applyHook(_ m: HookMessage) {
        let now = Date()
        switch m.event {
        case "SessionStart":
            upsert(m.session, cwd: m.cwd, phase: .running, now: now)
        case "UserPromptSubmit", "PostToolUse":
            upsert(m.session, cwd: m.cwd, phase: .running, now: now)
        case "PreToolUse", "Notification":
            upsert(m.session, cwd: m.cwd, phase: .running,
                   activity: activityLabel(m), now: now)
        case "PermissionRequest":
            upsert(m.session, cwd: m.cwd, phase: .waitingPermission,
                   activity: activityLabel(m), pendingTool: m.tool, pendingDetail: m.detail, now: now)
        case "Stop", "SessionEnd", "SubagentStop":
            upsert(m.session, cwd: m.cwd, phase: .ended, now: now)
        default:
            break
        }
        prune(now: now)
    }

    /// User tapped 允许 / 拒绝 on a local session's permission card.
    public func resolveLocalPermission(_ session: String, allow: Bool) {
        if let i = localSessions.firstIndex(where: { $0.id == session }) {
            localSessions[i].phase = .running
            localSessions[i].pendingTool = nil
            localSessions[i].pendingDetail = nil
            localSessions[i].updatedAt = Date()
        }
        resolvePermission?(session, allow)
    }

    private func activityLabel(_ m: HookMessage) -> String? {
        if let detail = m.detail, !detail.isEmpty { return detail }
        return m.tool
    }

    private func upsert(_ id: String, cwd: String?, phase: LocalSession.Phase,
                        activity: String? = nil, pendingTool: String? = nil,
                        pendingDetail: String? = nil, now: Date) {
        if let i = localSessions.firstIndex(where: { $0.id == id }) {
            if let cwd, !cwd.isEmpty { localSessions[i].cwd = cwd }
            localSessions[i].phase = phase
            if let activity { localSessions[i].activity = activity }
            localSessions[i].pendingTool = pendingTool
            localSessions[i].pendingDetail = pendingDetail
            localSessions[i].updatedAt = now
        } else {
            localSessions.append(LocalSession(
                id: id, cwd: cwd ?? "", phase: phase, activity: activity,
                pendingTool: pendingTool, pendingDetail: pendingDetail, updatedAt: now))
        }
        localSessions.sort { a, b in
            if a.isActive != b.isActive { return a.isActive }  // active first
            return a.updatedAt > b.updatedAt                    // then newest first
        }
    }

    /// Drop ended sessions after a short grace period; cap the list length.
    private func prune(now: Date) {
        localSessions.removeAll { $0.phase == .ended && now.timeIntervalSince($0.updatedAt) > 90 }
        if localSessions.count > 6 {
            localSessions = Array(localSessions.prefix(6))
        }
    }

    public func toggleExpanded() {
        expanded.toggle()
        if !expanded { captureStatus = .idle }
    }

    /// Hover-driven expand: open immediately on enter, collapse after a short
    /// grace period on exit so brief mouse slips don't flap the panel. A pending
    /// capture (non-empty text) keeps it open even if the pointer leaves.
    /// When set, the panel ignores hover (stays as-is) — debug/screenshot aid.
    public var hoverPinned = false

    public func hover(_ inside: Bool) {
        if hoverPinned { return }
        collapseTask?.cancel()
        if inside {
            expanded = true
            return
        }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard let self, !Task.isCancelled else { return }
            // Locked (mid-interaction) or with pending text → stay open.
            if !self.locked && self.captureText.isEmpty { self.collapse() }
        }
    }

    /// Click the 速记 cell → lock the panel open for keyboard input.
    public func beginCapture() {
        collapseTask?.cancel()
        expanded = true
        locked = true
    }

    /// Leave interaction mode (Esc / send / click-away) without forcing collapse.
    public func endInteraction() {
        locked = false
    }

    public func collapse() {
        collapseTask?.cancel()
        expanded = false
        locked = false
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
