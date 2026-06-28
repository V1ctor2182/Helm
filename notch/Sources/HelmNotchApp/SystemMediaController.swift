import Foundation
import HelmNotchCore

/// Real now-playing via the private MediaRemote framework. On macOS 15.4+ the
/// system withholds this data from an unsigned binary — the callback simply
/// never delivers — so `nowPlaying()` races the callback against a 2s timeout
/// and reports nil (the notch shows no media) rather than hanging the poll loop.
///
/// Making this actually return data needs a signed app with the right
/// entitlements, or vendoring boring.notch's `mediaremote-adapter`. Tracked as a
/// ticket; wired here so it lights up for free once that lands.
final class SystemMediaController: MediaController, @unchecked Sendable {
    private typealias GetInfoFn = @convention(c) (DispatchQueue, @escaping ([String: Any]) -> Void) -> Void
    private typealias SendCommandFn = @convention(c) (Int, CFDictionary?) -> Bool

    private let getInfo: GetInfoFn?
    private let sendCommand: SendCommandFn?

    init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        getInfo = handle
            .flatMap { dlsym($0, "MRMediaRemoteGetNowPlayingInfo") }
            .map { unsafeBitCast($0, to: GetInfoFn.self) }
        sendCommand = handle
            .flatMap { dlsym($0, "MRMediaRemoteSendCommand") }
            .map { unsafeBitCast($0, to: SendCommandFn.self) }
    }

    func nowPlaying() async -> NowPlaying? {
        guard let getInfo else { return nil }
        let box = ResumeOnce()
        return await withCheckedContinuation { (continuation: CheckedContinuation<NowPlaying?, Never>) in
            let finish: @Sendable (NowPlaying?) -> Void = { value in
                if box.claim() { continuation.resume(returning: value) }
            }
            getInfo(DispatchQueue.global(qos: .userInitiated)) { dict in
                guard let title = dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String else {
                    finish(nil)
                    return
                }
                let artist = dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String ?? ""
                let rate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0
                finish(NowPlaying(title: title, artist: artist, isPlaying: rate > 0))
            }
            // Restriction guard: if the callback never fires, resume nil after 2s.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { finish(nil) }
        }
    }

    // MediaRemote command codes.
    func playPause() { _ = sendCommand?(2, nil) }      // kMRTogglePlayPause
    func nextTrack() { _ = sendCommand?(4, nil) }      // kMRNextTrack
    func previousTrack() { _ = sendCommand?(5, nil) }  // kMRPreviousTrack
}

/// One-shot resume guard so the continuation resumes exactly once (callback or
/// timeout, whichever wins).
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false
    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
