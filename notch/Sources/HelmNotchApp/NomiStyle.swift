import HelmNotchCore
import SwiftUI

/// NOMI 样式原语 — 设计稿的 .wcard/.gbtn/.kbtn/.pbtn/渐变的 SwiftUI 对应物。
/// 视图统一走这里取样式,别在各处手写十六进制。
enum Nomi {
    /// 橙紫渐变(--g1→--g2),135° 对角。
    static let gradient = LinearGradient(
        colors: [Color(NomiTheme.g1), Color(NomiTheme.g2)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    /// 横向渐变(gbtn / 进度条用 90°)。
    static let gradientH = LinearGradient(
        colors: [Color(NomiTheme.g1), Color(NomiTheme.g2)],
        startPoint: .leading, endPoint: .trailing)
    /// 竖向渐变(波形柱/日程竖条用 180°)。
    static let gradientV = LinearGradient(
        colors: [Color(NomiTheme.g1), Color(NomiTheme.g2)],
        startPoint: .top, endPoint: .bottom)

    static let ok = Color(NomiTheme.ok)
    static let warn = Color(NomiTheme.warn)
    static let bad = Color(NomiTheme.bad)

    /// 设计稿全局缓动 cubic-bezier(.32,.72,0,1)。
    static func ease(_ duration: Double) -> Animation {
        .timingCurve(0.32, 0.72, 0, 1, duration: duration)
    }
}

extension View {
    /// `.wcard`:卡片底+14 圆角;dark 用发丝边替代阴影(设计稿 .shell.dark 规则),
    /// light 用柔和投影。
    func wcard(_ p: NomiPalette, dark: Bool, radius: CGFloat = 14) -> some View {
        background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color(p.cardBG)))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(dark ? Color(p.hair) : .clear, lineWidth: 1))
            .shadow(color: dark ? .clear : .black.opacity(0.07), radius: 9, y: 3)
            .shadow(color: dark ? .clear : .black.opacity(0.05), radius: 1, y: 1)
    }
}

/// `.gbtn`:渐变胶囊主按钮(白字)。
struct GradientButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.horizontal, 18).padding(.vertical, 8)
            .background(Capsule().fill(Nomi.gradientH))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// `.kbtn`:ink 底胶囊按钮(onInk 字)。
struct InkButtonStyle: ButtonStyle {
    let palette: NomiPalette
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color(palette.onInk))
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(Color(palette.ink)))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// `.pbtn`:pill 底小按钮(ink2 字)。
struct PillButtonStyle: ButtonStyle {
    let palette: NomiPalette
    var fontSize: CGFloat = 10.5
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize)).foregroundStyle(Color(palette.ink2))
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(Capsule().fill(Color(palette.pill)))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// `.spark`:12px 渐变圆点(conic 徽记的近似)。
struct SparkDot: View {
    var size: CGFloat = 12
    var body: some View {
        Circle().fill(AngularGradient(
            colors: [Color(NomiTheme.g1), Color(NomiTheme.g2), Color(NomiTheme.g1)],
            center: .center, angle: .degrees(210)))
            .frame(width: size, height: size)
    }
}
