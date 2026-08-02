import AppKit
import os
import UniformTypeIdentifiers

@MainActor
final class FinderActionHandler {
    static let shared = FinderActionHandler()

    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderActionHandler")

    private init() {}

    func handle(_ commandURL: URL) {
        guard commandURL.scheme == "findertools",
              let components = URLComponents(url: commandURL, resolvingAgainstBaseURL: false),
              let action = components.host else {
            logger.error("Ignored an invalid Finder action URL")
            return
        }

        let values = Dictionary(grouping: components.queryItems ?? [], by: \.name)
            .mapValues { $0.compactMap(\.value) }

        do {
            switch action {
            case "create":
                guard let directoryPath = values["directory"]?.first,
                      let fileExtension = values["type"]?.first else {
                    throw FinderActionError.invalidCommand
                }
                let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
                guard let accessToken = FolderAccessManager.shared.beginAccess(to: [directoryURL]) else {
                    requestFolderAuthorization(for: commandURL)
                    return
                }
                try createFile(in: directoryURL, fileExtension: fileExtension)
                _ = accessToken

            case "terminal":
                guard let directoryPath = values["directory"]?.first else {
                    throw FinderActionError.invalidCommand
                }
                let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
                guard let accessToken = FolderAccessManager.shared.beginAccess(to: [directoryURL]) else {
                    requestFolderAuthorization(for: commandURL)
                    return
                }
                openInTerminal(directoryURL, accessToken: accessToken)

            case "open":
                guard let applicationPath = values["application"]?.first else {
                    throw FinderActionError.invalidCommand
                }
                let itemURLs = (values["item"] ?? []).map { URL(fileURLWithPath: $0) }
                guard !itemURLs.isEmpty else { throw FinderActionError.invalidCommand }
                guard let accessToken = FolderAccessManager.shared.beginAccess(to: itemURLs) else {
                    requestFolderAuthorization(for: commandURL)
                    return
                }
                open(itemURLs, with: URL(fileURLWithPath: applicationPath), accessToken: accessToken)

            case "choose":
                let itemURLs = (values["item"] ?? []).map { URL(fileURLWithPath: $0) }
                guard !itemURLs.isEmpty else { throw FinderActionError.invalidCommand }
                guard let accessToken = FolderAccessManager.shared.beginAccess(to: itemURLs) else {
                    requestFolderAuthorization(for: commandURL)
                    return
                }
                chooseApplication(for: itemURLs, accessToken: accessToken)

            default:
                throw FinderActionError.invalidCommand
            }
        } catch {
            logger.error("Finder action failed: \(error.localizedDescription, privacy: .public)")
            showError("操作失败", message: error.localizedDescription)
        }
    }

    private func createFile(in directoryURL: URL, fileExtension: String) throws {
        let supportedExtensions = [
            "txt", "docx", "xlsx", "pptx", "md", "rtf", "csv", "json",
            "yaml", "html", "css", "js", "swift", "py"
        ]
        guard supportedExtensions.contains(fileExtension) else {
            throw FinderActionError.unsupportedFileType
        }

        let destinationURL = uniqueDestinationURL(in: directoryURL, fileExtension: fileExtension)

        if ["docx", "xlsx", "pptx"].contains(fileExtension) {
            guard let plugInsURL = Bundle.main.builtInPlugInsURL,
                  let extensionBundle = Bundle(
                    url: plugInsURL.appendingPathComponent("FinderToolsExtension.appex", isDirectory: true)
                  ),
                  let templateURL = extensionBundle.url(forResource: "blank", withExtension: fileExtension) else {
                throw FinderActionError.missingTemplate(fileExtension)
            }
            try FileManager.default.copyItem(at: templateURL, to: destinationURL)
        } else {
            let contents = initialContents(for: fileExtension)
            try contents.write(to: destinationURL, options: .withoutOverwriting)
        }

        logger.notice("Created file: \(destinationURL.path, privacy: .public)")
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
    }

    private func initialContents(for fileExtension: String) -> Data {
        let text: String
        switch fileExtension {
        case "md":
            text = "# 未命名\n"
        case "rtf":
            text = "{\\rtf1\\ansi\n}"
        case "json":
            text = "{\n}\n"
        case "yaml":
            text = "---\n"
        case "html":
            text = """
            <!doctype html>
            <html lang="zh-CN">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>未命名</title>
            </head>
            <body>

            </body>
            </html>

            """
        case "swift":
            text = "import Foundation\n\n"
        default:
            text = ""
        }
        return Data(text.utf8)
    }

    private func open(_ itemURLs: [URL], with applicationURL: URL, accessToken: FolderAccessToken) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(
            itemURLs,
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { [logger, accessToken] _, error in
            _ = accessToken
            if let error {
                logger.error("Could not open selection: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self.showError("无法打开", message: error.localizedDescription)
                }
            }
        }
    }

    private func openInTerminal(_ directoryURL: URL, accessToken: FolderAccessToken) {
        guard let terminalURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Terminal"
        ) else {
            showError("无法打开终端", message: "这台 Mac 上找不到系统自带的“终端”软件。")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false

        NSWorkspace.shared.open(
            [directoryURL],
            withApplicationAt: terminalURL,
            configuration: configuration
        ) { [logger, accessToken] _, error in
            _ = accessToken
            if let error {
                logger.error("Could not open directory in Terminal: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor in
                    self.showError("无法打开终端", message: error.localizedDescription)
                }
            }
        }
    }

    private func chooseApplication(for itemURLs: [URL], accessToken: FolderAccessToken) {
        NSApp.activate(ignoringOtherApps: true)

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

    private func requestFolderAuthorization(for commandURL: URL) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要文件夹权限"
        alert.informativeText = "请选择包含当前项目的文件夹。你可以只授权桌面、下载等需要使用的位置，并在“扩展权限”页面中随时添加或移除。"
        alert.addButton(withTitle: "选择文件夹")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn,
              FolderAccessManager.shared.chooseFolder() != nil else { return }
        handle(commandURL)
    }

    private func uniqueDestinationURL(in directoryURL: URL, fileExtension: String) -> URL {
        var index = 1

        while true {
            let suffix = index == 1 ? "" : " \(index)"
            let candidate = directoryURL.appendingPathComponent("未命名\(suffix).\(fileExtension)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func showError(_ title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}

private enum FinderActionError: LocalizedError {
    case invalidCommand
    case unsupportedFileType
    case missingTemplate(String)

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            "Finder 传来的操作内容不完整。"
        case .unsupportedFileType:
            "不支持这种文件类型。"
        case .missingTemplate(let fileExtension):
            "找不到 .\(fileExtension) 空白模板。"
        }
    }
}
