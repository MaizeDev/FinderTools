import Foundation

/// 第 19 步：哪些位置不允许授权、不允许执行操作。
///
/// 纯逻辑，不依赖 AppKit；路径比较统一走 `PathContainment`：
/// 先展开符号链接，再按目标卷的大小写规则逐段比较。
///
/// 规则分两类：
/// 1. `restrictedTargetSubtrees`：目标位于这些目录**及其子目录**时，不请求授权，直接提示“此位置不支持”。
///    系统目录里的操作不应该通过 FinderTools 授权完成。
/// 2. `restrictedRootLocations`：这些“根级别”位置不能选作授权文件夹，本身也不能作为操作目标：
///    - 作为授权文件夹：会一次授权整块系统盘 / 所有磁盘 / 所有用户目录 / 整个 /Applications；
///    - 作为操作目标：任何能覆盖它的文件夹都在禁用清单里，永远无法合法授权，所以直接判为不支持。
///    注意这是“仅根”规则：`/Volumes/某块盘`、`/Users/name`、`/Applications/某 App.app` 都不在禁用清单里。
nonisolated enum AuthorizationLocationPolicy {
    /// 目标位于这些目录及其子目录时一律不支持。
    ///
    /// `/etc`、`/var`、`/tmp` 是 `/private/...` 的符号链接。注意 macOS 27 的 Foundation
    /// 会把 `/private/tmp` 规范化为 `/tmp`（`/private/var` → `/var`、`/private/etc` → `/etc`），
    /// 所以两边的路径都要列出，否则 `/tmp` 这类路径会绕过 `/private` 规则。
    static let restrictedTargetSubtrees: [String] = [
        "/System",
        "/Library",
        "/usr",
        "/bin",
        "/sbin",
        "/private",
        "/dev",
        "/cores",
        "/Network",
        "/tmp",
        "/var",
        "/etc"
    ]

    /// 只能“整个根目录”被判为不支持 / 不可授权，子目录不受影响。
    static let restrictedRootLocations: [String] = [
        "/",
        "/Applications",
        "/Volumes",
        "/Users"
    ]

    /// 所有目标都允许时才返回 `true`。
    static func areTargetsSupported(_ targetURLs: [URL]) -> Bool {
        targetURLs.allSatisfy(isTargetSupported)
    }

    /// 目标的“位置”是否允许操作。只判断位置，不判断它是否已被授权。
    static func isTargetSupported(_ targetURL: URL) -> Bool {
        let canonicalURL = PathContainment.canonicalURL(targetURL)

        if canonicalURL.path == "/" {
            return false
        }

        if restrictedRootLocations.contains(where: { isSamePath(canonicalURL, $0) }) {
            return false
        }

        return !restrictedTargetSubtrees.contains { restrictedPath in
            PathContainment.isInside(canonicalURL, folder: URL(fileURLWithPath: restrictedPath))
        }
    }

    /// 该文件夹能否被选作授权文件夹。只判断文件夹本身，不判断它是否已被授权。
    static func canAuthorizeFolder(_ folderURL: URL) -> Bool {
        let canonicalURL = PathContainment.canonicalURL(folderURL)
        return !restrictedRootLocations.contains { isSamePath(canonicalURL, $0) }
    }

    /// 目标是否就是个人目录本身：授权它等于授权整个个人目录，授权提示里要额外提醒。
    ///
    /// `homeDirectory` 可注入，便于单元测试；默认用 `RealHome.url`
    /// （沙盒里的 `homeDirectoryForCurrentUser` 是容器目录，不能用）。
    static func isPersonalHomeDirectory(
        _ targetURL: URL,
        homeDirectory: URL = RealHome.url
    ) -> Bool {
        PathContainment.areEquivalent(targetURL, homeDirectory)
    }

    /// 两个路径是否指向同一位置。
    ///
    /// 用“双向包含”而不是 `PathContainment.areEquivalent`：第二个方向里第一个参数
    /// 是已存在的受限目录（如 `/System`），卷大小写规则因此总是从真实存在的路径读取；
    /// 在区分大小写的卷上，`/system` 不会被误判成 `/System`（D-09 的规则仍是唯一来源）。
    private static func isSamePath(_ url: URL, _ restrictedPath: String) -> Bool {
        let restrictedURL = URL(fileURLWithPath: restrictedPath)
        return PathContainment.isInside(url, folder: restrictedURL)
            && PathContainment.isInside(restrictedURL, folder: url)
    }
}
