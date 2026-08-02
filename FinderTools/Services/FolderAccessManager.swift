import AppKit
import os

@MainActor
final class FolderAccessManager {
    static let shared = FolderAccessManager()

    private let bookmarksKey = "authorizedFolderBookmarks"
    private let legacyBookmarkKey = "authorizedFolderBookmark"
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FolderAccess")

    private init() {}

    var authorizedFolders: [URL] {
        resolveBookmarks().map(\.url)
    }

    @discardableResult
    func chooseFolder() -> URL? {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.title = "授权 FinderTools 使用文件夹"
        panel.message = "只会授权你这次选择的文件夹。之后可以继续添加桌面、下载、文稿等其他位置。"
        panel.prompt = "添加授权"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let folderURL = panel.url else { return nil }

        do {
            let data = try folderURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let normalizedURL = folderURL.standardizedFileURL
            let existingBookmarks = resolveBookmarks()
            let alreadyAuthorized = existingBookmarks.contains {
                $0.url.standardizedFileURL.path == normalizedURL.path
            }

            if !alreadyAuthorized {
                let bookmarkData = existingBookmarks.map(\.data) + [data]
                UserDefaults.standard.set(bookmarkData, forKey: bookmarksKey)
            }
            logger.notice("Authorized folder: \(normalizedURL.path, privacy: .public)")
            return normalizedURL
        } catch {
            logger.error("Could not save folder authorization: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func removeAuthorization(for folderURL: URL) {
        let pathToRemove = folderURL.standardizedFileURL.path
        let remainingBookmarks = resolveBookmarks()
            .filter { $0.url.standardizedFileURL.path != pathToRemove }
            .map(\.data)

        UserDefaults.standard.set(remainingBookmarks, forKey: bookmarksKey)
        logger.notice("Removed folder authorization: \(pathToRemove, privacy: .public)")
    }

    func beginAccess(to targetURLs: [URL]) -> FolderAccessToken? {
        guard !targetURLs.isEmpty else { return nil }

        let authorizedFolders = resolveBookmarks().map(\.url)
        var foldersToAccess: [URL] = []

        for targetURL in targetURLs {
            guard let matchingFolder = authorizedFolders
                .filter({ targetURL.isInside($0) })
                .max(by: { $0.standardizedFileURL.path.count < $1.standardizedFileURL.path.count })
            else {
                return nil
            }

            if !foldersToAccess.contains(where: {
                $0.standardizedFileURL.path == matchingFolder.standardizedFileURL.path
            }) {
                foldersToAccess.append(matchingFolder)
            }
        }

        var accessedFolders: [URL] = []
        for folderURL in foldersToAccess {
            guard folderURL.startAccessingSecurityScopedResource() else {
                accessedFolders.reversed().forEach { $0.stopAccessingSecurityScopedResource() }
                logger.error("A saved folder authorization could not be activated")
                return nil
            }
            accessedFolders.append(folderURL)
        }

        return FolderAccessToken(folderURLs: accessedFolders)
    }

    private func storedBookmarkData() -> [Data] {
        if let bookmarks = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] {
            return bookmarks
        }

        guard let legacyBookmark = UserDefaults.standard.data(forKey: legacyBookmarkKey) else {
            return []
        }

        UserDefaults.standard.set([legacyBookmark], forKey: bookmarksKey)
        UserDefaults.standard.removeObject(forKey: legacyBookmarkKey)
        return [legacyBookmark]
    }

    private func resolveBookmarks() -> [ResolvedBookmark] {
        let storedData = storedBookmarkData()
        var resolvedBookmarks: [ResolvedBookmark] = []
        var seenPaths = Set<String>()

        for data in storedData {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                let normalizedURL = resolvedURL.standardizedFileURL
                guard seenPaths.insert(normalizedURL.path).inserted else { continue }

                let currentData = if isStale {
                    try normalizedURL.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                } else {
                    data
                }

                resolvedBookmarks.append(ResolvedBookmark(data: currentData, url: normalizedURL))
            } catch {
                logger.error("Could not restore a folder authorization: \(error.localizedDescription, privacy: .public)")
            }
        }

        let normalizedData = resolvedBookmarks.map(\.data)
        if normalizedData != storedData {
            UserDefaults.standard.set(normalizedData, forKey: bookmarksKey)
        }

        return resolvedBookmarks
    }
}

final class FolderAccessToken: @unchecked Sendable {
    private let folderURLs: [URL]

    init(folderURLs: [URL]) {
        self.folderURLs = folderURLs
    }

    deinit {
        folderURLs.reversed().forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

private struct ResolvedBookmark {
    let data: Data
    let url: URL
}

private extension URL {
    func isInside(_ folderURL: URL) -> Bool {
        let folderPath = folderURL.standardizedFileURL.path
        let targetPath = standardizedFileURL.path
        return targetPath == folderPath || targetPath.hasPrefix(folderPath.hasSuffix("/") ? folderPath : folderPath + "/")
    }
}
