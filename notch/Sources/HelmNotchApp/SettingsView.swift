import HelmNotchCore
import SwiftUI

/// The settings window: install/uninstall the Claude Code monitoring hook, and
/// pick the accent-color mode (daily / hue / fixed).
struct SettingsView: View {
    @Bindable var model: NotchModel
    @State private var installed = ClaudeHookInstaller.isInstalled()
    @State private var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Helm Notch 设置").font(.system(size: 15, weight: .bold))

            // MARK: Local monitoring
            VStack(alignment: .leading, spacing: 8) {
                Label("本机 Claude Code 监听", systemImage: "dot.radiowaves.left.and.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("在 ~/.claude/settings.json 安装 hook,刘海即可显示本机 Claude Code 的运行/等权限状态,并在刘海上允许/拒绝。安装前会自动备份。")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Circle().fill(installed ? .green : .secondary).frame(width: 7, height: 7)
                    Text(installed ? "已安装" : "未安装").font(.system(size: 11))
                    Spacer()
                    if installed {
                        Button("卸载") { run { try ClaudeHookInstaller.uninstall(); note = "已卸载,Claude Code 重启后生效" } }
                    } else {
                        Button("安装 hook") { run { let b = try ClaudeHookInstaller.install(); note = b == nil ? "已安装" : "已安装(原配置已备份)" } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                if let note { Text(note).font(.system(size: 10)).foregroundStyle(.secondary) }
            }

            Divider()

            // MARK: Theme — daily auto-rotation, nothing to configure
            VStack(alignment: .leading, spacing: 8) {
                Label("强调色", systemImage: "paintpalette")
                    .font(.system(size: 12, weight: .semibold))
                HStack(spacing: 8) {
                    Circle().fill(Color(model.accent)).frame(width: 16, height: 16)
                    Text("每天自动轮换 · 今日色").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Text("折叠条保持黑底,只有强调色 + 底部光晕随当日色走,午夜自动切换。无需设置。")
                    .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 380, height: 360)
        .onAppear { installed = ClaudeHookInstaller.isInstalled() }
    }

    private func run(_ work: () throws -> Void) {
        do { try work() } catch { note = "失败:\(error.localizedDescription)" }
        installed = ClaudeHookInstaller.isInstalled()
    }
}
