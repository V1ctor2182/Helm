// Helm.app — Swift + WKWebView 壳(MVP):
// ① 拉起 python -m helm(仅当 8769 没在跑;退出只杀自己拉起的);
// ② 主窗口 WKWebView 加载产品页(HELM_SHELL_URL 可覆盖,如指 5174 走 vite 热更新);
// ③ 标准 ⌘ 菜单(Edit 菜单必须有,否则 WKWebView 里 ⌘C/V/X/A 全失灵);
// ④ 关窗驻留(Dock 点击复开);_blank 外链交系统浏览器。
// 前端/后端零改动——壳只是"窗户和门"。

import AppKit
import WebKit

// MARK: - 后端生命周期

@MainActor
final class BackendProcess {
    static let base = URL(string: "http://127.0.0.1:8769")!
    private var child: Process?
    private(set) var spawnedByUs = false

    /// helm 仓根:env HELM_ROOT > Info.plist HelmRoot(打包时烘焙)> 开发默认。
    static func helmRoot() -> URL {
        if let p = ProcessInfo.processInfo.environment["HELM_ROOT"], !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        if let p = Bundle.main.object(forInfoDictionaryKey: "HelmRoot") as? String, !p.isEmpty {
            return URL(fileURLWithPath: (p as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("work/AI-workspace/helm")
    }

    func healthy() async -> Bool {
        var req = URLRequest(url: Self.base.appendingPathComponent("healthz"))
        req.timeoutInterval = 1.5
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    /// 确保后端在跑;返回 false = 起不来(缺 venv 等),窗口会显示指引。
    func ensureRunning() async -> Bool {
        if await healthy() { return true }  // 已有实例(比如你在终端跑着)→ 直接用,退出时不杀
        let root = Self.helmRoot()
        let python = root.appendingPathComponent(".venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: python.path) else { return false }

        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Helm")
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logURL = logDir.appendingPathComponent("backend.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try? FileHandle(forWritingTo: logURL)
        _ = try? log?.seekToEnd()

        let p = Process()
        p.executableURL = python
        p.arguments = ["-m", "helm"]
        p.currentDirectoryURL = root
        p.standardOutput = log
        p.standardError = log
        do { try p.run() } catch { return false }
        child = p
        spawnedByUs = true

        for _ in 0..<60 {  // 最多等 12s(冷启动含向量库初始化)
            if await healthy() { return true }
            try? await Task.sleep(for: .milliseconds(200))
        }
        return false
    }

    func stop() {
        guard spawnedByUs, let child, child.isRunning else { return }
        child.terminate()  // SIGTERM,uvicorn 会体面收尾
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate,
    WKScriptMessageHandler {
    let backend = BackendProcess()
    var window: NSWindow!
    var webView: WKWebView!

    var shellURL: URL {
        if let s = ProcessInfo.processInfo.environment["HELM_SHELL_URL"], let u = URL(string: s) {
            return u  // 开发:HELM_SHELL_URL=http://localhost:5174 走热更新
        }
        return BackendProcess.base
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        Task {
            let ok = await backend.ensureRunning()
            if ok {
                webView.load(URLRequest(url: shellURL))
            } else {
                showSetupHint()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        backend.stop()
    }

    // 关窗驻留:最后一扇窗关掉不退出,Dock 点击复开
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { window.makeKeyAndOrderFront(nil) }
        return true
    }

    private func buildWindow() {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = true
        // 网页标题栏 mousedown → 原生 performDrag(网页自绘 chrome,拖拽得由壳代劳)
        config.userContentController.add(self, name: "helmDrag")
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        // UA 标记:前端据此隐藏自绘假交通灯并给真灯让位
        webView.customUserAgent = (webView.value(forKey: "userAgent") as? String ?? "Mozilla/5.0") + " HelmShell/0.1"
        if #available(macOS 13.3, *) { webView.isInspectable = true }  // Safari 开发者工具可连

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Helm"
        // 沉浸式:原生标题栏透明,真交通灯直接落在网页标题栏那一行(网页假灯由 UA 分支隐藏)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 1100, height: 700)
        window.contentView = webView
        window.backgroundColor = .black
        window.center()
        window.setFrameAutosaveName("HelmMainWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        guard message.name == "helmDrag" else { return }
        Task { @MainActor in
            if let event = NSApp.currentEvent { self.window.performDrag(with: event) }
        }
    }

    private func showSetupHint() {
        let html = """
        <body style="background:#000;color:#c9c9cf;font:13px ui-monospace;padding:48px;line-height:2">
        <h2 style="color:#fff">Helm 后端没起来</h2>
        <p>壳找不到可用的后端(127.0.0.1:8769)。检查:</p>
        <p>1. helm 仓路径:<b>\(BackendProcess.helmRoot().path)</b>(可用 HELM_ROOT 覆盖)<br>
        2. 该路径下存在 .venv(python -m venv .venv && pip install -e .)<br>
        3. 或手动起:cd 仓根 && .venv/bin/python -m helm,再重开本 App</p>
        <p>日志:~/Library/Logs/Helm/backend.log</p></body>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // _blank / window.open → 系统浏览器(预览的 ⧉ 新窗、外链都走这)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    // 后端还没就绪时的加载失败 → 1s 后重试(冷启动竞态兜底)
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let url = shellURL
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            webView.load(URLRequest(url: url))
        }
    }

    private func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Helm", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 Helm", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Helm", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // Edit 菜单:没有它,WKWebView 里 ⌘C/V/X/A/Z 全部失灵
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)

        let viewItem = NSMenuItem()
        let view = NSMenu(title: "显示")
        let reload = NSMenuItem(title: "重新加载", action: #selector(reloadPage), keyEquivalent: "r")
        reload.target = self
        view.addItem(reload)
        viewItem.submenu = view
        main.addItem(viewItem)

        let windowItem = NSMenuItem()
        let win = NSMenu(title: "窗口")
        win.addItem(withTitle: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        win.addItem(withTitle: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = win
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }

    @objc private func reloadPage() {
        webView.reload()
    }
}

@main
@MainActor
enum HelmShellMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
