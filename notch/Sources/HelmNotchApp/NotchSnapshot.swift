import AppKit
import HelmNotchCore
import SwiftUI

/// Headless snapshot mode (`HelmNotchApp --snapshot <dir>`): renders each notch
/// view to a PNG via `ImageRenderer` — no window, no GUI session — so the Swift
/// UI can be visually diffed against the HTML design targets.
enum NotchSnapshot {
    @MainActor
    static func render(to dir: String) {
        _ = NSApplication.shared  // ImageRenderer wants an app object present

        let views: [(name: String, configure: (NotchModel) -> Void)] = [
            ("dash", { $0.module = .dashboard }),
            ("media", { $0.module = .media }),
            ("media-lyrics", {
                $0.module = .media
                $0.debugSetMedia(
                    NowPlaying(title: "Mask Off (Remix)", artist: "Future", isPlaying: true,
                               elapsed: 40, duration: 204),
                    lyrics: .synced((0..<20).map {
                        LyricLine(time: Double($0) * 10, text: "Line \($0) — call it how it is")
                    }))
            }),
            ("media-nolyrics", {
                $0.module = .media
                $0.debugSetMedia(
                    NowPlaying(title: "Lose Yourself", artist: "Eminem", isPlaying: true,
                               elapsed: 163, duration: 327),
                    lyrics: .none)
            }),
            ("media-plain", {
                $0.module = .media
                $0.debugSetMedia(
                    NowPlaying(title: "dishonesty", artist: "Gareth.T", isPlaying: true,
                               elapsed: 30, duration: 179),
                    lyrics: .plain((0..<30).map { "纯文本第 \($0) 行,比较长比较长比较长" }))
            }),
            ("cap", { $0.module = .capture; $0.captureKind = .note }),
            ("cal-month", { $0.module = .calendar; $0.calMonthView = true }),
            ("cal-week", { $0.module = .calendar; $0.calMonthView = false }),
            ("dev-agents", { $0.module = .dev; $0.devSection = .agents }),
            ("dev-ports", { $0.module = .dev; $0.devSection = .ports }),
            ("dev-stats", { $0.module = .dev; $0.devSection = .stats }),
            ("clip", { $0.module = .clipboard }),
            ("collapsed", { $0.expanded = false }),
            ("banner-permission", {
                $0.applyHook(HookMessage(event: "PermissionRequest", session: "notch",
                                         cwd: "~/notch", tool: "Edit",
                                         detail: "src/auth/middleware.ts", reply: true))
            }),
            ("banner-ask", {
                // toolInput 走通选择题解析 → QuestionBannerView(notch 内可作答)。
                $0.applyHook(HookMessage(
                    event: "PermissionRequest", session: "notch", cwd: "~/kaggle",
                    tool: "AskUserQuestion",
                    detail: "你本地能跑那两个评分模型吗?",
                    reply: true,
                    toolInput: #"""
                    {"questions":[{"question":"你本地能跑那两个评分模型吗(GPT-OSS-20B 和 Gemma、4-bit GGUF)?","header":"算力","multiSelect":false,"options":[{"label":"能,有 GPU / 好机器","description":"本地全量跑"},{"label":"只有这台 Mac","description":"4-bit 勉强"},{"label":"不想本地跑模型","description":"云上跑"}]}]}
                    """#))
            }),
            ("dev-agent-detail", {
                $0.module = .dev
                $0.devSection = .agents
                $0.applyHook(HookMessage(
                    event: "UserPromptSubmit", session: "s-detail", cwd: "~/work/helm/notch",
                    prompt: "优化 notch 的 vibeisland 效果,可以点开会话看详情、回答问题",
                    term: "ghostty", tmuxPane: "%3"))
                $0.applyHook(HookMessage(
                    event: "Stop", session: "s-detail",
                    assistant: "三块能力已经落地:选择题横幅在 notch 内直接作答(答案经阻塞 hook 的 updatedInput 注回 CLI);Dev/Agents 点行进详情;idle 会话可从 notch 注入回复到 tmux/Ghostty。"))
                $0.selectedLocalSessionID = "s-detail"
            }),
            ("mat-darkglass", { $0.module = .dashboard; $0.backgroundMaterial = .darkGlass }),
            ("mat-lightglass", { $0.module = .dashboard; $0.backgroundMaterial = .lightGlass }),
            ("mat-vibrant", { $0.module = .dashboard; $0.backgroundMaterial = .vibrant }),
        ]

        for entry in views {
            let model = NotchModel(backend: HelmClient())
            model.expanded = true
            model.hoverPinned = true
            entry.configure(model)

            // Banner states override the expanded panel with their own size.
            let banner: CGSize? = model.reminder != nil
                ? CGSize(width: 560, height: 152)
                : (model.localSessions.contains(where: \.needsAttention) ? model.bannerSize : nil)
            let w = (banner?.width ?? CGFloat(model.expandedWidth)) + 80
            let h = (banner?.height ?? CGFloat(model.expanded ? model.autoExpandedHeight : 32)) + 60
            let content = NotchView(model: model)
                .frame(width: w, height: h, alignment: .top)
                .background(Color(white: 0.16))

            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                FileHandle.standardError.write(Data("snapshot failed: \(entry.name)\n".utf8))
                continue
            }
            let url = URL(fileURLWithPath: dir).appendingPathComponent("swift-\(entry.name).png")
            try? png.write(to: url)
            print("wrote \(url.path)")
        }

        // Settings modal (a separate window in the real app).
        let sModel = NotchModel(backend: HelmClient())
        let settings = SettingsView(model: sModel).content
            .frame(width: 440, alignment: .topLeading)
            .background(Color(red: 0.086, green: 0.090, blue: 0.098))
        let sr = ImageRenderer(content: settings)
        sr.scale = 2
        if let img = sr.nsImage, let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let png = bitmap.representation(using: .png, properties: [:]) {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("swift-settings.png")
            try? png.write(to: url)
            print("wrote \(url.path)")
        }
    }
}
