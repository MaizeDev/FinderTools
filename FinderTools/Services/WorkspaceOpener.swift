import AppKit
import os
import UniformTypeIdentifiers

/// `open` / `terminal` / `choose` 动作：通过 `NSWorkspace` 打开 App 或终端。
///
/// `accessToken` 必须活到异步打开完成，所以由调用方传入并在闭包里持有。
@MainActor
enum WorkspaceOpener {
    private static let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderActionHandler")

    static func open(_ itemURLs: [URL], with applicationURL: URL, accessToken: FolderAccessToken) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        // 显式捕获 Logger（Sendable 值），避免在 Sendable 闭包里引用 MainActor 隔离的静态属性。
        let logger = WorkspaceOpener.logger
        NSWorkspace.shared.open(
            itemURLs,
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { [logger, accessToken] _, error in
            _ = accessToken
            if let error {
                logger.error("Could not open selection: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    ActionAlerts.showError("无法打开", message: error.localizedDescription)
                }
            }
        }
    }

    static func openInTerminal(_ directoryURL: URL, accessToken: FolderAccessToken) {
        guard let terminalURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Terminal"
        ) else {
            ActionAlerts.showError("无法打开终端", message: "这台 Mac 上找不到系统自带的“终端”软件。")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false

        // 显式捕获 Logger（Sendable 值），避免在 Sendable 闭包里引用 MainActor 隔离的静态属性。
        let logger = WorkspaceOpener.logger
        NSWorkspace.shared.open(
            [directoryURL],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { [logger, accessToken] _, error in
            _ = accessToken
            if let error {
                logger.error("Could not open directory in Terminal: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    ActionAlerts.showError("无法打开终端", message: error.localizedDescription)
                }
            }
        }
    }

    static func chooseApplication(for itemURLs: [URL], accessToken: FolderAccessToken) {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.title = "选择用于打开的软件"
        panel.prompt = "选择"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]

        guard panel.runModal() == .OK, let applicationURL = panel.url else { return }
        open(itemURLs, with: applicationURL, accessToken: accessToken)
    }
}
