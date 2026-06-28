import HelmNotchCore
import SwiftUI

/// The notch surface. Collapsed: a brand + connection-dot pill. Tap to expand
/// into the Journal quick-capture form (速记/日记/任务) that posts to Helm.
struct NotchView: View {
    @Bindable var model: NotchModel

    var body: some View {
        Group {
            if model.expanded {
                expanded
            } else {
                collapsed
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: model.expanded ? 16 : 16, style: .continuous)
                .fill(.black)
        )
    }

    // MARK: Collapsed pill

    private var collapsed: some View {
        HStack(spacing: 8) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            Text("Helm")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 4)
            Text(statusText)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture { model.toggleExpanded() }
    }

    // MARK: Expanded capture form

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(CaptureKind.allCases) { kind in
                    Button(kind.label) { model.captureKind = kind }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: model.captureKind == kind ? .semibold : .regular))
                        .foregroundStyle(model.captureKind == kind ? .white : .white.opacity(0.45))
                }
                Spacer()
                Button { model.toggleExpanded() } label: {
                    Image(systemName: "xmark").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.5))
            }

            TextField(placeholder, text: $model.captureText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(2...4)
                .onSubmit { Task { await model.submit() } }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.08)))

            HStack {
                statusLabel
                Spacer()
                Button("发送") { Task { await model.submit() } }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(model.captureText.isEmpty ? .white.opacity(0.3) : .white)
                    .disabled(model.captureText.isEmpty)
            }
        }
        .padding(12)
    }

    private var placeholder: String {
        switch model.captureKind {
        case .note: "随手记一笔…"
        case .journal: "今天发生了什么?"
        case .task: "到点让 agent 做什么…"
        }
    }

    @ViewBuilder private var statusLabel: some View {
        switch model.captureStatus {
        case .idle: EmptyView()
        case .sending: Text("发送中…").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
        case .sent: Text("已记录 ✓").font(.system(size: 10)).foregroundStyle(.green)
        case .failed: Text("失败,重试").font(.system(size: 10)).foregroundStyle(.red)
        }
    }

    // MARK: Status helpers

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
