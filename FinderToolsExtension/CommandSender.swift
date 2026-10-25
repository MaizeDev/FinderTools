import AppKit
import os

/// 把菜单动作拼成 `findertools://` URL 并发给主 App（D-02）。
nonisolated struct CommandSender {
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderSync")

    func createFile(in directoryURL: URL, fileExtension: String) {
        send(
            action: "create",
            queryItems: [
                URLQueryItem(name: "directory", value: directoryURL.path),
                URLQueryItem(name: "type", value: fileExtension)
            ]
        )
    }

    func openInTerminal(directoryURL: URL) {
        send(
            action: "terminal",
            queryItems: [URLQueryItem(name: "directory", value: directoryURL.path)]
        )
    }

    func open(items itemURLs: [URL], applicationPath: String) {
        var queryItems = [URLQueryItem(name: "application", value: applicationPath)]
        queryItems.append(contentsOf: itemURLs.map { URLQueryItem(name: "item", value: $0.path) })
        send(action: "open", queryItems: queryItems)
    }

    func chooseOther(items itemURLs: [URL]) {
        send(
            action: "choose",
            queryItems: itemURLs.map { URLQueryItem(name: "item", value: $0.path) }
        )
    }

    private func send(action: String, queryItems: [URLQueryItem]) {
        var components = URLComponents()
        components.scheme = "findertools"
        components.host = action
        components.queryItems = queryItems

        guard let commandURL = components.url else {
            logger.error("Could not send Finder action to the main app")
            return
        }

        let mainAppIsRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.wheat.FinderTools"
        ).isEmpty
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.hides = !mainAppIsRunning

        NSWorkspace.shared.open(commandURL, configuration: configuration) { [logger] _, error in
            if let error {
                logger.error("Could not send Finder action to the main app: \(error.localizedDescription, privacy: .public)")
            }
        }
        logger.notice("Sent Finder action to the main app: \(action, privacy: .public)")
    }
}
