import HelmNotchCore
import SwiftUI

/// Helm 娃娃脸 logo — 设计稿 #helm-logo SVG(viewBox 24×18)的 Path 移植:
/// 外框 + 两只圆角脚"眼睛" + 两道圆头"眉毛"弧线。
struct HelmLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 24, sy = rect.height / 18
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy) }
        var p = Path()
        // 眼睛(填充):左 M4.02,10.07 H5.82 C→(9.47,13.71) V14.06 H4.02 Z
        for dx in [0.0, 8.7] {
            p.move(to: pt(4.02 + dx, 10.07))
            p.addLine(to: pt(5.82 + dx, 10.07))
            p.addCurve(to: pt(9.47 + dx, 13.71),
                       control1: pt(7.84 + dx, 10.07), control2: pt(9.47 + dx, 11.70))
            p.addLine(to: pt(9.47 + dx, 14.06))
            p.addLine(to: pt(4.02 + dx, 14.06))
            p.closeSubpath()
        }
        return p
    }
}

struct HelmLogoView: View {
    var color: Color = .white
    var size: CGFloat = 19

    var body: some View {
        let h = size * 14 / 19
        Canvas { ctx, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            let sx = rect.width / 24, sy = rect.height / 18
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            let stroke = 1.78 * sx
            // 外框
            var frame = Path()
            frame.addRect(CGRect(x: 0.89 * sx, y: 0.89 * sy, width: 21.33 * sx, height: 16.04 * sy))
            ctx.stroke(frame, with: .color(color), lineWidth: stroke)
            // 眼睛
            ctx.fill(HelmLogoShape().path(in: rect), with: .color(color))
            // 眉毛:M3.25,8.89 C4.31,8.10 7.06,6.99 9.47,8.89(圆头)
            for dx in [0.0, 9.09] {
                var brow = Path()
                brow.move(to: pt(3.25 + dx, 8.89))
                brow.addCurve(to: pt(9.47 + dx, 8.89),
                              control1: pt(4.31 + dx, 8.10), control2: pt(7.06 + dx, 6.99))
                ctx.stroke(brow, with: .color(color),
                           style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            }
        }
        .frame(width: size, height: h)
    }
}

/// 折叠态波形 — 4 根渐变柱,scaleY 交替呼吸(设计稿 .hw .wave,1s ease 无限)。
struct WaveBars: View {
    var heights: [CGFloat] = [5, 10, 7, 11]
    @State private var shrunk = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Nomi.gradientV)
                    .frame(width: 2.5, height: heights[i])
                    .scaleEffect(y: shrunk ? 0.45 : 1, anchor: .bottom)
                    .animation(
                        Nomi.ease(1.0).repeatForever(autoreverses: true).delay(Double(i) * 0.15),
                        value: shrunk)
            }
        }
        .frame(height: 12, alignment: .bottom)
        .onAppear { shrunk = true }
    }
}

/// 折叠态迷你封面 18×18(有封面用封面,无封面用深底+音符)。
struct MiniCover: View {
    let artwork: NSImage?

    var body: some View {
        Group {
            if let artwork {
                Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [Color(red: 0.23, green: 0.18, blue: 0.09), Color(red: 0.11, green: 0.11, blue: 0.13)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8)))
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
