import Foundation

/// Now-playing snapshot for the notch media row.
public struct NowPlaying: Sendable, Equatable {
    public let title: String
    public let artist: String
    public let isPlaying: Bool
    /// Base64-encoded artwork (PNG/JPEG bytes), if the source provided it.
    public let artworkBase64: String?
    /// Playback position at capture time, in seconds (nil when unknown).
    public let elapsed: Double?
    /// Track length in seconds (nil when unknown / live stream).
    public let duration: Double?

    public init(
        title: String,
        artist: String,
        isPlaying: Bool,
        artworkBase64: String? = nil,
        elapsed: Double? = nil,
        duration: Double? = nil
    ) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.artworkBase64 = artworkBase64
        self.elapsed = elapsed
        self.duration = duration
    }

    public var subtitle: String { artist.isEmpty ? "" : artist }

    /// Whether a determinate progress bar can be shown.
    public var hasProgress: Bool { (duration ?? 0) > 0 }
}

/// The player the notch's transport controls (HTML `SOURCES` + `S.mediaSrc`).
/// Names are plain text — no brand logos (project rule [[helm-no-emoji-ui]]).
public enum MediaSource: String, Sendable, CaseIterable, Identifiable {
    case system
    case appleMusic
    case spotify
    case browser

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: "System"
        case .appleMusic: "Apple Music"
        case .spotify: "Spotify"
        case .browser: "Browser"
        }
    }
}

/// System media access, behind a protocol so the core is testable with a fake
/// (the real implementation pokes the private MediaRemote framework, which is
/// macOS-version-sensitive — see `SystemMediaController` in the App target).
public protocol MediaController: Sendable {
    func nowPlaying() async -> NowPlaying?
    func playPause()
    func nextTrack()
    func previousTrack()
}

/// Default no-op controller — used when no system media source is wired (keeps
/// the media row empty rather than crashing).
public struct NoMediaController: MediaController {
    public init() {}
    public func nowPlaying() async -> NowPlaying? { nil }
    public func playPause() {}
    public func nextTrack() {}
    public func previousTrack() {}
}
