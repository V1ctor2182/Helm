import Foundation

/// NOMI 皮肤的成套色板 — 对齐只读设计稿 docs/design/helm-notch-nomi.html 的
/// CSS 变量(:root = light,.shell.dark = dark)。夜间为默认;两套之间整体切换,
/// 不允许单点混用。渐变 accent(g1→g2)与状态色不随模式变。
public struct NomiPalette: Sendable, Equatable {
    public let ink: RGB      // 主文字
    public let ink2: RGB     // 次级文字
    public let ink3: RGB     // 三级/占位
    public let pill: RGB     // 胶囊/控件底
    public let hair: RGB     // 发丝线
    public let cardBG: RGB   // 卡片底(wcard)
    public let onInk: RGB    // ink 底上的前景(kbtn 文字)
    public let shellBG: RGB  // 面板底
    public let logo: RGB     // 顶行 logo 色

    /// 深色(shell.dark,默认)。
    public static let dark = NomiPalette(
        ink: RGB(hex: "f2f2f4"), ink2: RGB(hex: "c2c2ca"), ink3: RGB(hex: "84848e"),
        pill: RGB(hex: "232327"), hair: RGB(hex: "2a2a2e"),
        cardBG: RGB(hex: "1d1d21"), onInk: RGB(hex: "111114"),
        shellBG: RGB(hex: "0f0f11"), logo: RGB(hex: "f2f2f4"))

    /// 浅色(:root)。
    public static let light = NomiPalette(
        ink: RGB(hex: "111114"), ink2: RGB(hex: "5c5c66"), ink3: RGB(hex: "a2a2ab"),
        pill: RGB(hex: "f1f1f3"), hair: RGB(hex: "ececef"),
        cardBG: RGB(hex: "ffffff"), onInk: RGB(hex: "ffffff"),
        shellBG: RGB(hex: "ffffff"), logo: RGB(hex: "271C11"))
}

/// 模式无关的 NOMI 常量。
public enum NomiTheme {
    /// 橙紫渐变两端(--g1/--g2)— NOMI 的唯一 accent 语言。
    public static let g1 = RGB(hex: "ff8a3d")
    public static let g2 = RGB(hex: "a855f7")
    /// 状态色(--ok/--warn/--bad),不随模式/渐变变化。
    public static let ok = RGB(hex: "28a745")
    public static let warn = RGB(hex: "ff9500")
    public static let bad = RGB(hex: "e5484d")

    /// 壳几何(设计稿 .shell/.shell.open/.shell.bannermode.open)。
    public static let foldedWidth: Double = 310
    public static let foldedHeight: Double = 34
    public static let openWidth: Double = 440
    public static let bannerWidth: Double = 460
    public static let foldedRadius: Double = 14
    public static let openRadius: Double = 26
}
