import AppKit
import os

@MainActor
final class FolderAccessManager {
    static let shared = FolderAccessManager()

    private let store = FolderAuthorizationStore()
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FolderAccess")

    private init() {}

    /// 只读接口：绝不写 `UserDefaults`。
    /// 暂时解析失败的记录以 `isAvailable == false` 返回，但仍留在结果里（B-01）。
    var authorizedFolders: [AuthorizedFolder] {
        store.resolvedRecords()
    }

    /// 已授权文件夹的路径列表（只读，不写存储）。
    ///
    /// 第 19 步起扩展不再用它限制菜单出现范围；主 App 仍随设置段广播这份路径，
    /// 只为兼容升级期间还在运行的旧扩展进程与回滚版本。目录暂时不可用（外置硬盘
    /// 未挂载、被改名）时退回最后已知路径，这样硬盘插回后不需要重新授权；
    /// 排序后再发，避免每次广播因顺序不同被误判成变化。
    var authorizedFolderPaths: [String] {
        store.resolvedRecords()
            .compactMap { $0.url?.path(percentEncoded: false) }
            .sorted()
    }

    /// - Parameters:
    ///   - suggestedDirectory: 授权面板默认定位到的目录，通常是用户要操作的目标目录。
    ///     传 `nil` 时退回真实用户主目录（沙盒里不能用 `homeDirectoryForCurrentUser`，见 `RealHome`）。
    ///   - title / message / prompt: 第 19 步允许“用到时再授权”的流程复用同一个面板，
    ///     换成“需要文件夹权限 / 列出目标路径 / 授权”的文案。
    @discardableResult
    func chooseFolder(
        suggestedDirectory: URL? = nil,
        title: String = "授权 FinderTools 使用文件夹",
        message: String = "只会授权你这次选择的文件夹。之后可以继续添加桌面、下载、文稿等其他位置。",
        prompt: String = "添加授权"
    ) -> URL? {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.directoryURL = suggestedDirectory ?? RealHome.url
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let folderURL = panel.url else { return nil }

        // 第 19 步：根目录与根级系统位置不能选作授权文件夹。
        // 这里只提示一次并结束，不再重新弹面板，避免出现循环。
        guard AuthorizationLocationPolicy.canAuthorizeFolder(folderURL) else {
            logger.notice(
                "Rejected an authorization folder that cannot be authorized: \(folderURL.path, privacy: .public)"
            )
            ActionAlerts.showUnsupportedAuthorizationFolder(folderURL)
            return nil
        }

        do {
            let bookmarkData = try folderURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let normalizedURL = folderURL.standardizedFileURL

            // 基于完整记录（含暂时不可用的记录）判断重复，而不是“解析成功的书签”。
            // D-09：用统一的大小写/符号链接规则比较，避免同一文件夹因大小写差异重复授权。
            var records = store.storedRecords()
            let alreadyAuthorized = records.contains { record in
                if PathContainment.areEquivalent(URL(fileURLWithPath: record.lastKnownPath), normalizedURL) {
                    return true
                }
                guard let resolvedPath = store.resolvedPath(of: record.bookmarkData) else { return false }
                return PathContainment.areEquivalent(URL(fileURLWithPath: resolvedPath), normalizedURL)
            }

            if !alreadyAuthorized {
                records.append(StoredFolderAuthorization(
                    id: UUID(),
                    bookmarkData: bookmarkData,
                    lastKnownPath: normalizedURL.path
                ))
                store.persist(records)
                // 第 19 步：扩展不再用授权路径限制菜单；这里仍广播一次设置段，
                // 让升级期间还在运行的旧扩展进程和回滚版本继续收到最新的授权变化。
                FinderMenuPreferences.notifyExtension()
            }

            logger.notice("Authorized folder: \(normalizedURL.path, privacy: .public)")
            return normalizedURL
        } catch {
            logger.error("Could not save folder authorization: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// 按持久化记录移除，不依赖“解析出来的 URL”，所以不可用的文件夹也能移除。
    func removeAuthorization(for folder: AuthorizedFolder) {
        var records = store.storedRecords()
        records.removeAll { $0.id == folder.id }
        store.persist(records)
        // 第 19 步：扩展不再用授权路径限制菜单；广播设置段只为兼容旧扩展进程与回滚版本。
        FinderMenuPreferences.notifyExtension()
        logger.notice("Removed folder authorization: \(folder.pathDescription, privacy: .public)")
    }

    func beginAccess(to targetURLs: [URL]) -> FolderAccessToken? {
        guard !targetURLs.isEmpty, let foldersToAccess = matchingFolders(for: targetURLs) else { return nil }

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

    /// 只读：判断目标是否已被某个可用的授权文件夹覆盖。
    /// 用于授权后确认目标已被覆盖；不会开始访问，也不写存储。
    func isAuthorized(_ targetURL: URL) -> Bool {
        matchingFolders(for: [targetURL]) != nil
    }

    /// 只读：为每个目标找出覆盖它的最深层授权文件夹，并跳过不可用记录
    /// （例如外置硬盘没插时不可能开始访问）。
    private func matchingFolders(for targetURLs: [URL]) -> [URL]? {
        let accessibleFolders = store.resolvedRecords()
            .filter(\.isAvailable)
            .compactMap(\.url)

        var folders: [URL] = []

        for targetURL in targetURLs {
            guard let matchingFolder = accessibleFolders
                .filter({ PathContainment.isInside(targetURL, folder: $0) })
                .max(by: {
                    PathContainment.canonicalPath($0).count < PathContainment.canonicalPath($1).count
                })
            else {
                return nil
            }

            if !folders.contains(where: {
                PathContainment.areEquivalent($0, matchingFolder)
            }) {
                folders.append(matchingFolder)
            }
        }

        return folders
    }

    /// 迁移旧格式并重建过期书签。**这是唯一会写 `UserDefaults` 的公开方法。**
    ///
    /// 调用时机：`PermissionView` 出现（`.task`）、点“刷新状态”、添加或移除授权之后。
    /// 读取方法（`authorizedFolders`、`beginAccess`）都不会调用它。
    ///
    /// - 只在新键不存在时迁移一次；新键一旦存在就绝不回头读旧键，
    ///   否则用户已移除的文件夹会被旧数据迁回来。
    /// - 解析失败的记录原样保留；只有成功得到新书签数据（或成功解析出路径）时才写回。
    func refreshAuthorizations() {
        let pathsBeforeRefresh = authorizedFolderPaths
        var records = store.storedRecords()
        var changed = store.needsMigration

        for index in records.indices {
            guard let resolution = store.resolve(records[index].bookmarkData) else {
                // 暂时解析失败（外置硬盘未挂载、文件夹被改名等）：原样保留，不自作删除。
                logger.notice("A saved folder authorization is currently unavailable: \(records[index].lastKnownPath, privacy: .public)")
                continue
            }

            let normalizedURL = resolution.url

            if records[index].lastKnownPath != normalizedURL.path {
                records[index].lastKnownPath = normalizedURL.path
                changed = true
            }

            guard resolution.isStale else { continue }

            // 重建过期书签前先取得安全作用域访问权限，重建后（即使失败）再释放。
            let didStartAccess = normalizedURL.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    normalizedURL.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let refreshedData = try normalizedURL.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                records[index].bookmarkData = refreshedData
                changed = true
                logger.notice("Rebuilt a stale folder authorization: \(normalizedURL.path, privacy: .public)")
            } catch {
                // 重建失败：保留原来的书签数据，绝不删除。
                logger.error("Could not rebuild a stale folder authorization, keeping stored data: \(error.localizedDescription, privacy: .public)")
            }
        }

        if changed {
            store.persist(records)
        }

        // 第 19 步：扩展不再用授权路径限制菜单；授权变化时仍广播设置段，
        // 让旧扩展进程与回滚版本继续收到最新的授权列表。
        if authorizedFolderPaths != pathsBeforeRefresh {
            FinderMenuPreferences.notifyExtension()
        }
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
