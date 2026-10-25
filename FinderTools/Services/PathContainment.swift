import Foundation

/// D-09：授权判断的路径比较只保留一份规则。
///
/// 之前 `FolderAccessManager` 与 `ActionValidator` 各写了一次“前缀 + 大小写敏感”的判断，
/// 在 APFS 默认不区分大小写的卷上会误判，也没有处理符号链接。现在统一为：
/// 1. 先展开符号链接，再标准化 URL（消除 `/private`、`..`、结尾斜杠等差异）；
/// 2. 大小写规则跟随目标卷——区分大小写的卷按原样比较，其余按不区分大小写比较；
/// 3. 按路径组件逐段比较，`Desktop-old` 不会被当成 `Desktop` 的子路径。
nonisolated enum PathContainment {
    /// 用于比较的规范路径：展开符号链接后再标准化。
    static func canonicalPath(_ url: URL) -> String {
        canonicalURL(url).path
    }

    static func canonicalURL(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    /// `target` 等于 `folder` 或位于 `folder` 之内时返回 `true`。
    static func isInside(_ target: URL, folder: URL) -> Bool {
        isPrefix(canonicalURL(folder), of: canonicalURL(target))
    }

    /// 两个 URL 指向同一路径。用于“这个文件夹是否已经授权过”的去重。
    static func areEquivalent(_ lhs: URL, _ rhs: URL) -> Bool {
        let lhsURL = canonicalURL(lhs)
        let rhsURL = canonicalURL(rhs)
        return isPrefix(lhsURL, of: rhsURL) && isPrefix(rhsURL, of: lhsURL)
    }

    private static func isPrefix(_ base: URL, of candidate: URL) -> Bool {
        let baseComponents = base.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count >= baseComponents.count else { return false }

        let isCaseSensitive = isCaseSensitiveVolume(base)
        return zip(baseComponents, candidateComponents).allSatisfy { baseComponent, candidateComponent in
            isCaseSensitive
                ? baseComponent == candidateComponent
                : baseComponent.compare(candidateComponent, options: .caseInsensitive) == .orderedSame
        }
    }

    /// 目标卷是否区分大小写。取不到卷信息时按 macOS 默认（APFS 不区分大小写）处理。
    private static func isCaseSensitiveVolume(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.volumeSupportsCaseSensitiveNamesKey]),
           let isCaseSensitive = values.volumeSupportsCaseSensitiveNames {
            return isCaseSensitive
        }
        return false
    }
}
