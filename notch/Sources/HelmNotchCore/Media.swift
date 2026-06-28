import Foundation

/// Now-playing snapshot for the notch media row. Artwork comes in a later pass.
public struct NowPlaying: Sendable, Equatable {
    public let title: String
    public let artist: String
    public let isPlaying: Bool

    public init(title: String, artist: String, isPlaying: Bool) {
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
    }

    public var subtitle: String { artist.isEmpty ? "" : artist }
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
