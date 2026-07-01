import HelmNotchCore
import SwiftUI

/// The settings window — restyled to match the `settingsHTML` modal in
/// helm-notch-pro.html: a dark, sectioned sheet (外观 / HELM 后端 / 本机 Claude
/// Code / 媒体). Only controls with real backing are wired; material/autostart/
/// autohide from the HTML aren't ported (no backend) — see TODOs.
struct SettingsView: View {
    @Bindable var model: NotchModel
    @State private var installed = ClaudeHookInstaller.isInstalled()
    @State private var note: String?

    private let t1 = Color.white
    private let t2 = Color.white.opacity(0.56)
    private let t3 = Color.white.opacity(0.34)
    private let hair = Color.white.opacity(0.09)
    private var accent: Color { Color(model.accent) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                section("外观")
                rowLabel("背景材质", sub: "玻璃材质会透出壁纸(默认纯黑)")
                materialPicker.padding(.vertical, 4)
                rowLabel("主题色", sub: "驱动选中 / 聚焦 / 进度 / 折叠态波形")
                palette.padding(.vertical, 4)
                rowLabel("配色模式", sub: "每日轮换 · 连续色相 · 固定")
                modePicker.padding(.bottom, 6)
                tapRow("随机一套", sub: "背景+主题随机,自动保证对比清晰", action: "随机 ↻") {
                    model.randomTheme()
                }
                toggleRow("每天随机一套", sub: "背景+主题每天自动换,保证对比清晰", isOn: $model.dailyRandomTheme)

                section("HELM 后端")
                connectionRow
                tapRow("打开 Helm 完整设置", sub: "在 Helm 主窗里配置", action: "打开 ›") {
                    // TODO(align-settings): bridge to the Helm main window.
                    note = "打开 Helm 完整设置 · /settings"
                }

                section("本机 CLAUDE CODE")
                hookRow
                if let note { Text(note).font(.system(size: 10)).foregroundStyle(t3).padding(.top, 4) }

                section("媒体")
                tapRow("默认播放源", sub: "折叠态控制的播放器", action: "\(model.mediaSource.label) ⌄") {
                    model.cycleMediaSource()
                }
            }
            .padding(18)
        }
        .background(Color(red: 0.086, green: 0.090, blue: 0.098))
        .frame(minWidth: 440, minHeight: 520)
        .onAppear { installed = ClaudeHookInstaller.isInstalled() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(spacing: 8) {
            Text("设置").font(.system(size: 15, weight: .heavy)).foregroundStyle(t1)
            Spacer()
            Text("Helm Notch v0.1").font(.system(size: 10, design: .monospaced)).foregroundStyle(t3)
        }
        .padding(.bottom, 6)
    }

    private func section(_ title: String) -> some View {
        Text(title.uppercased()).font(.system(size: 9, weight: .bold)).tracking(0.6)
            .foregroundStyle(t3).padding(.top, 14).padding(.bottom, 4)
    }

    private func rowLabel(_ name: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t1)
            Text(sub).font(.system(size: 10)).foregroundStyle(t3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    /// 10 accent swatches; tapping one pins it (fixed mode at that index).
    private var palette: some View {
        HStack(spacing: 9) {
            ForEach(Theme.palette.indices, id: \.self) { i in
                let selected = model.themeMode == .fixed && model.fixedColorIndex == i
                Circle().fill(Color(Theme.palette[i]))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.white, lineWidth: selected ? 2 : 0).padding(-2))
                    .contentShape(Circle())
                    .onTapGesture { model.themeMode = .fixed; model.fixedColorIndex = i }
            }
        }
    }

    private var materialPicker: some View {
        HStack(spacing: 8) {
            ForEach(NotchMaterial.allCases) { mat in
                let on = model.backgroundMaterial == mat
                Button { model.backgroundMaterial = mat } label: {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 5).fill(matSwatch(mat)).frame(width: 16, height: 16)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.18), lineWidth: 0.5))
                        Text(mat.label).font(.system(size: 11)).foregroundStyle(on ? .white : t2)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 9).fill(.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(on ? accent : .white.opacity(0.09), lineWidth: on ? 1 : 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func matSwatch(_ mat: NotchMaterial) -> Color {
        switch mat {
        case .black: Color.black
        case .darkGlass: Color(white: 0.16)
        case .lightGlass: Color.white.opacity(0.55)
        case .vibrant: Color(red: 0.4, green: 0.3, blue: 0.8)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(ThemeMode.allCases) { mode in
                let on = model.themeMode == mode
                Button { model.themeMode = mode } label: {
                    Text(mode.label).font(.system(size: 11, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Color(red: 0.1, green: 0.07, blue: 0.03) : t2)
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Capsule().fill(on ? accent : .white.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var connectionRow: some View {
        let (dot, text): (Color, String) = {
            switch model.connection {
            case .connected(let v): (.green, "已连接 · v\(v)")
            case .disconnected: (.red, "未连接")
            case .unknown: (.yellow, "连接中…")
            }
        }()
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("连接").font(.system(size: 13, weight: .semibold)).foregroundStyle(t1)
                Text("Helm 后端").font(.system(size: 10)).foregroundStyle(t3)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(text).font(.system(size: 11)).foregroundStyle(t2)
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    private var hookRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("监听 hook").font(.system(size: 13, weight: .semibold)).foregroundStyle(t1)
                Text("~/.claude/settings.json · 安装前自动备份").font(.system(size: 10)).foregroundStyle(t3)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(installed ? .green : t3).frame(width: 7, height: 7)
                if installed {
                    Button("卸载") { run { try ClaudeHookInstaller.uninstall(); note = "已卸载,重启 Claude Code 生效" } }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(accent)
                } else {
                    Button("安装 hook") { run { let b = try ClaudeHookInstaller.install(); note = b == nil ? "已安装" : "已安装(原配置已备份)" } }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                }
            }
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    private func toggleRow(_ name: String, sub: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t1)
                Text(sub).font(.system(size: 10)).foregroundStyle(t3)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(accent)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    private func tapRow(_ name: String, sub: String, action: String, _ perform: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(t1)
                Text(sub).font(.system(size: 10)).foregroundStyle(t3)
            }
            Spacer()
            Button(action: perform) {
                Text(action).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(hair).frame(height: 0.5) }
    }

    private func run(_ work: () throws -> Void) {
        do { try work() } catch { note = "失败:\(error.localizedDescription)" }
        installed = ClaudeHookInstaller.isInstalled()
    }
}
