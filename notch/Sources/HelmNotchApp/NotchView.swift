import HelmNotchCore
import SwiftUI

/// The pill shown at the notch. m1: brand + a connection dot to the Helm
/// backend. Later milestones fill this with journal capture, agent cards and
/// now-playing media.
struct NotchView: View {
    @Bindable var model: NotchModel

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text("Helm")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 4)
            Text(statusText)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(.black))
    }

    private var dotColor: Color {
        switch model.connection {
        case .connected: .green
        case .disconnected: .red
        case .unknown: .yellow
        }
    }

    private var statusText: String {
        switch model.connection {
        case .connected(let version): "v\(version)"
        case .disconnected: "离线"
        case .unknown: "…"
        }
    }
}
