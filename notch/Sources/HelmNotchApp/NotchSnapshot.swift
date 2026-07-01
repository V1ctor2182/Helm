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
                : (model.localSessions.contains(where: \.needsAttention) ? CGSize(width: 620, height: 208) : nil)
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
