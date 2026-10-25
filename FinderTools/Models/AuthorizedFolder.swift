import Foundation

/// 一个已授权的文件夹，供界面展示。
///
/// - `isAvailable == false`：存储里的书签数据仍然保留，但当前无法解析
///   （外置硬盘未挂载、文件夹被移除/改名、权限失效等）。这类条目必须留在列表里，
///   仍然允许用户移除。
/// - `url == nil`：旧版数据迁移时既解析不出路径、也没有记录过最后已知路径，
///   只能显示为“未知文件夹”；它不是权限丢失，记录仍在存储中。
struct AuthorizedFolder: Identifiable, Hashable {
    let id: UUID
    let url: URL?
    let isAvailable: Bool

    var displayName: String {
        guard let url else { return "未知文件夹" }
        return url.lastPathComponent.isEmpty ? url.path(percentEncoded: false) : url.lastPathComponent
    }

    var pathDescription: String {
        guard let url else { return "原位置未知，可能是旧版授权数据；可移除后重新添加" }
        let path = url.path(percentEncoded: false)
        return isAvailable ? path : "暂时无法访问：\(path)"
    }
}

/// `UserDefaults` 中持久化的一条授权记录。
///
/// 书签数据必须原样保存：解析失败时不能丢弃，否则外置硬盘没插时打开一次 App
/// 就永久失去授权（B-01）。另外保存最后已知路径，用于不可用时在界面上显示和定位。
struct StoredFolderAuthorization: Codable, Hashable {
    let id: UUID
    var bookmarkData: Data
    var lastKnownPath: String
}
