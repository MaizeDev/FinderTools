import Foundation
import os

/// 授权书签的持久化与解析，从 `FolderAccessManager` 拆出。
///
/// - 读取方法（`storedRecords`、`resolvedRecords`）绝不写 `UserDefaults`。
/// - 只有 `persist(_:)` 会写；旧键 `authorizedFolderBookmarks` /
///   `authorizedFolderBookmark` 只读、不删除，留作回退。
struct FolderAuthorizationStore {
    private let entriesKey = "authorizedFolderEntries"
    private let legacyBookmarksKey = "authorizedFolderBookmarks"
    private let legacyBookmarkKey = "authorizedFolderBookmark"
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FolderAccess")

    /// 书签解析结果。`isStale` 表示可以（也需要）用当前 URL 重新生成书签数据。
    struct BookmarkResolution {
        let url: URL
        let isStale: Bool
    }

    /// 新键缺失，说明还没做过一次性迁移。
    var needsMigration: Bool {
        UserDefaults.standard.object(forKey: entriesKey) == nil
    }

    /// 读取完整记录（只读）。
    /// 新键存在时只认新键；不存在时在内存里把旧格式转换成记录，写入由调用方决定。
    func storedRecords() -> [StoredFolderAuthorization] {
        if let data = UserDefaults.standard.data(forKey: entriesKey) {
            do {
                return try JSONDecoder().decode([StoredFolderAuthorization].self, from: data)
            } catch {
                // 新键已存在但无法解码：不能回退去读旧键，否则可能把已移除的文件夹迁回来。
                logger.error("Could not decode stored folder authorizations: \(error.localizedDescription, privacy: .public)")
                return []
            }
        }

        return legacyRecords()
    }

    /// 解析全部记录并构造展示模型（只读）。
    /// 解析失败的记录以 `isAvailable == false` 返回，绝不丢弃。
    func resolvedRecords() -> [AuthorizedFolder] {
        storedRecords().map { record in
            if let resolution = resolve(record.bookmarkData) {
                return AuthorizedFolder(
                    id: record.id,
                    url: resolution.url,
                    isAvailable: true
                )
            }

            let fallbackURL = record.lastKnownPath.isEmpty ? nil : URL(fileURLWithPath: record.lastKnownPath)
            return AuthorizedFolder(id: record.id, url: fallbackURL, isAvailable: false)
        }
    }

    func resolve(_ bookmarkData: Data) -> BookmarkResolution? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }
        return BookmarkResolution(url: url.standardizedFileURL, isStale: isStale)
    }

    func resolvedPath(of bookmarkData: Data) -> String? {
        resolve(bookmarkData)?.url.path
    }

    /// 唯一的写入点。旧键保持不动，方便回退。
    func persist(_ records: [StoredFolderAuthorization]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: entriesKey)
        } catch {
            logger.error("Could not save folder authorizations: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 旧格式（`[Data]` 数组或更旧的单条 `Data`）只在内存中转换成新记录。
    private func legacyRecords() -> [StoredFolderAuthorization] {
        let legacyData: [Data]
        if let bookmarks = UserDefaults.standard.array(forKey: legacyBookmarksKey) as? [Data] {
            legacyData = bookmarks
        } else if let bookmark = UserDefaults.standard.data(forKey: legacyBookmarkKey) {
            legacyData = [bookmark]
        } else {
            legacyData = []
        }

        return legacyData.map { data in
            StoredFolderAuthorization(
                id: UUID(),
                bookmarkData: data,
                lastKnownPath: resolvedPath(of: data) ?? ""
            )
        }
    }
}
