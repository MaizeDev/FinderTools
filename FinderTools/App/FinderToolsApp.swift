import AppKit
import os
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "AppDelegate")
    private var receivedFinderActionDuringLaunch = false
    private let dockIconVisibilityController = DockIconVisibilityController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ApplicationCatalog.shared.start()
        dockIconVisibilityController.start()

        // 第 20 步：登录项启动时只留在后台，不显示主窗口、不显示 Dock 图标。
        if LoginLaunchDetector.isLoginItemLaunch() {
            logger.notice("Launched as a login item; keeping the main window hidden")
            keepLoginLaunchInBackground()
            return
        }

        // LSUIElement keeps a background launch out of the Dock. A normal user
        // launch has no Finder command, so it becomes a regular foreground app.
        guard !receivedFinderActionDuringLaunch else { return }
        showForegroundApp(NSApp)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let commandURLs = urls.filter { $0.scheme == "findertools" }
        guard !commandURLs.isEmpty else { return }

        receivedFinderActionDuringLaunch = true
        logger.notice("Received \(commandURLs.count, privacy: .public) Finder action(s) in the background")
        for url in commandURLs {
            FinderActionHandler.shared.handle(url)
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showForegroundApp(sender)

        // A background Finder action can leave the initial window hidden. Reuse
        // that window instead of asking SwiftUI to create a duplicate.
        if !flag, let window = sender.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }

    private func showForegroundApp(_ application: NSApplication) {
        application.setActivationPolicy(.regular)
        application.unhide(nil)
        application.activate()
    }

    /// 登录项启动：保持 LSUIElement 的 accessory 激活策略，并立即移走 SwiftUI 创建的初始窗口。
    ///
    /// 实测（/tmp SwiftUI 探针）：在 `didFinishLaunching` 里对主窗口调用 `orderOut` 后，
    /// 窗口不会上屏；之后用户从“应用程序/Spotlight”打开时，`applicationShouldHandleReopen`
    /// 会恢复窗口与 Dock 图标。
    private func keepLoginLaunchInBackground() {
        NSApp.setActivationPolicy(.accessory)
        for window in NSApp.windows where window.canBecomeMain {
            window.orderOut(nil)
        }
    }
}

@main
struct FinderToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("FinderTools", id: "main") {
            ContentView()
                .environment(ApplicationCatalog.shared)
        }
        .defaultSize(width: 900, height: 620)
        .windowResizability(.contentMinSize)
        // Finder commands are handled by AppDelegate instead of being routed
        // through this scene. That keeps a closed main window closed.
        .handlesExternalEvents(matching: [])
        .commands {
            // FinderTools only needs one settings window. Removing the standard
            // New Window command prevents accidental duplicate windows while a
            // WindowGroup keeps the app running after its last window closes.
            CommandGroup(replacing: .newItem) {}
        }
    }
}
