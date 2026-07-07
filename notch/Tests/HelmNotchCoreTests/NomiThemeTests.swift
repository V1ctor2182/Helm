import XCTest

@testable import HelmNotchCore

/// NOMI 主题基建(B1):色板成套、深默认、几何常量对齐设计稿。
final class NomiThemeTests: XCTestCase {
    func testDarkPaletteMatchesDesignTokens() {
        let d = NomiPalette.dark
        XCTAssertEqual(d.shellBG, RGB(hex: "0f0f11"))
        XCTAssertEqual(d.cardBG, RGB(hex: "1d1d21"))
        XCTAssertEqual(d.ink, RGB(hex: "f2f2f4"))
        XCTAssertEqual(d.pill, RGB(hex: "232327"))
        XCTAssertEqual(d.hair, RGB(hex: "2a2a2e"))
        XCTAssertEqual(d.onInk, RGB(hex: "111114"))
    }

    func testLightPaletteMatchesDesignTokens() {
        let l = NomiPalette.light
        XCTAssertEqual(l.shellBG, RGB(hex: "ffffff"))
        XCTAssertEqual(l.ink, RGB(hex: "111114"))
        XCTAssertEqual(l.ink3, RGB(hex: "a2a2ab"))
        XCTAssertEqual(l.logo, RGB(hex: "271C11"))
    }

    func testGradientAndStatusConstants() {
        XCTAssertEqual(NomiTheme.g1, RGB(hex: "ff8a3d"))
        XCTAssertEqual(NomiTheme.g2, RGB(hex: "a855f7"))
        XCTAssertEqual(NomiTheme.ok, RGB(hex: "28a745"))
        XCTAssertEqual(NomiTheme.warn, RGB(hex: "ff9500"))
        XCTAssertEqual(NomiTheme.bad, RGB(hex: "e5484d"))
    }

    func testShellGeometryMatchesDesign() {
        XCTAssertEqual(NomiTheme.foldedWidth, 310)
        XCTAssertEqual(NomiTheme.foldedHeight, 34)
        XCTAssertEqual(NomiTheme.openWidth, 440)
        XCTAssertEqual(NomiTheme.bannerWidth, 460)
        XCTAssertEqual(NomiTheme.openRadius, 26)
    }

    @MainActor
    func testModelDefaultsToDarkAndSwitchesWholePalette() {
        let model = NotchModel(backend: FakeBackend())
        XCTAssertTrue(model.nomiDark)
        XCTAssertEqual(model.nomi, .dark)
        model.nomiDark = false
        XCTAssertEqual(model.nomi, .light)
    }
}
