import Foundation
import Testing

@testable import HelmNotchCore

@Suite struct LyricsTests {
    @Test func parsesLRCWithMultiTagsAndSorts() {
        let lrc = """
        [00:35.66] Look at the stars
        [ar: Coldplay]
        [01:10.5][00:38.46] Look how they shine for you
        garbage line
        """
        let lines = parseLRC(lrc)
        #expect(lines.count == 3)
        #expect(lines[0].text == "Look at the stars")
        #expect(abs(lines[0].time - 35.66) < 0.01)
        #expect(lines[1].text == "Look how they shine for you")  // 38.46 排在 70.5 前
        #expect(abs(lines[2].time - 70.5) < 0.01)
    }

    @Test func currentIndexFollowsPosition() {
        let lines = [LyricLine(time: 10, text: "a"), LyricLine(time: 20, text: "b")]
        #expect(currentLyricIndex(lines, position: 5) == -1)  // 前奏
        #expect(currentLyricIndex(lines, position: 10) == 0)
        #expect(currentLyricIndex(lines, position: 25) == 1)
    }

    @Test func fetcherPrefersSyncedAndFallsBack() async {
        let synced = LyricsFetcher(transport: { _ in
            Data(#"{"syncedLyrics":"[00:01.00] hi","plainLyrics":"hi"}"#.utf8)
        })
        if case .synced(let l) = await synced.fetch(title: "t", artist: "a", duration: 100) {
            #expect(l.first?.text == "hi")
        } else { Issue.record("expected synced") }

        let plain = LyricsFetcher(transport: { _ in
            Data(#"{"syncedLyrics":"","plainLyrics":"line1\nline2"}"#.utf8)
        })
        if case .plain(let p) = await plain.fetch(title: "t", artist: "a", duration: nil) {
            #expect(p == ["line1", "line2"])
        } else { Issue.record("expected plain") }

        let dead = LyricsFetcher(transport: { _ in throw URLError(.notConnectedToInternet) })
        #expect(await dead.fetch(title: "t", artist: "a", duration: nil) == .none)
    }
}
