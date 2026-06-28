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
            if let np = model.nowPlaying {
                Image(systemName: "music.note")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
                Text(np.title)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .frame(maxWidth: 80, alignment: .leading)
            }
            Spacer(minLength: 4)
            if model.activeAgentCount > 0 {
                Text("🤖\(model.activeAgentCount)")
                    .font(.system(size: 10))
                    .foregroundStyle(model.attentionCount > 0 ? .orange : .white.opacity(0.7))
            }
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
            if let np = model.nowPlaying {
                mediaRow(np)
                Divider().overlay(.white.opacity(0.12))
            }
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

            if !model.agents.isEmpty {
                agentsSection
            }
        }
        .padding(12)
    }

    private func mediaRow(_ np: NowPlaying) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(np.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !np.subtitle.isEmpty {
                    Text(np.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            Spacer()
            Button { model.previousTrack() } label: { Image(systemName: "backward.fill") }
            Button { model.playPause() } label: {
                Image(systemName: np.isPlaying ? "pause.fill" : "play.fill")
            }
            Button { model.nextTrack() } label: { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
        .foregroundStyle(.white)
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().overlay(.white.opacity(0.12))
            HStack {
                Text("Agents")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                if model.attentionCount > 0 {
                    Text("\(model.attentionCount) 待批准")
                        .font(.system(size: 9))
                        .foregroundStyle(.orange)
                }
            }
            ForEach(Array(model.agents.prefix(3))) { run in
                HStack(spacing: 6) {
                    Circle().fill(agentColor(run.status)).frame(width: 6, height: 6)
                    Text(run.prompt ?? "(无指令)")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                    Text(statusShort(run.status))
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func agentColor(_ status: String) -> Color {
        switch status {
        case "running": .green
        case "waiting_permission": .orange
        case "failed": .red
        case "completed": .white.opacity(0.4)
        default: .yellow
        }
    }

    private func statusShort(_ status: String) -> String {
        switch status {
        case "running": "运行中"
        case "waiting_permission": "待批准"
        case "completed": "完成"
        case "failed": "失败"
        case "pending": "排队"
        default: status
        }
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
