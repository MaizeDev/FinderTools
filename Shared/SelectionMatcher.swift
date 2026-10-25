import Foundation
import UniformTypeIdentifiers

/// 一个选中项的文件系统元数据（C-03）。
///
/// 扩展在真实运行时用 `SelectionItem.make(for:)` 读取；单元测试可以直接构造，
/// 因此 `SelectionMatcher` 保持纯逻辑、不依赖 AppKit。
nonisolated struct SelectionItem: Sendable {
    let url: URL
    let isDirectory: Bool
    let isPackage: Bool
    let contentTypeIdentifier: String?

    /// 通过 `resourceValues` 询问文件系统，不用 `URL.hasDirectoryPath`：
    /// 后者只看 URL 本身是否带目录标记，Finder 传来的 URL 不一定带。
    static func make(for url: URL) -> SelectionItem {
        let values = try? url.resourceValues(
            forKeys: [.isDirectoryKey, .isPackageKey, .contentTypeKey]
        )
        return SelectionItem(
            url: url,
            isDirectory: values?.isDirectory ?? false,
            isPackage: values?.isPackage ?? false,
            contentTypeIdentifier: values?.contentType?.identifier
        )
    }

    var filenameExtension: String { url.pathExtension.lowercased() }

    var contentType: UTType? {
        contentTypeIdentifier.flatMap { UTType($0) }
    }

    /// 选中的类型是否等于 App 声明的某个类型，或是它的子类型
    /// （例如 `public.go-source` 符合 `public.source-code`）。
    func matchesAny(of declaredTypeIdentifiers: [String]) -> Bool {
        guard let contentType else { return false }
        return declaredTypeIdentifiers.contains { identifier in
            if identifier == contentType.identifier { return true }
            guard let declaredType = UTType(identifier) else { return false }
            return contentType.conforms(to: declaredType)
        }
    }
}

/// 根据选中项和菜单快照决定应显示哪些 App（C-02 / C-03 / C-04）。
///
/// 纯逻辑，不依赖 AppKit（D-02；单元测试见 `FinderToolsTests/SelectionMatcherTests.swift`）。
nonisolated struct SelectionMatcher: Sendable {
    let allApplications: [ApplicationMenuOption]
    let applicationsByExtension: [String: [ApplicationMenuOption]]
    let directoryApplications: [ApplicationMenuOption]

    /// 扩展的运行入口：先读文件系统元数据，再交给纯逻辑匹配。
    func applications(for selectedURLs: [URL]) -> [ApplicationMenuOption] {
        applications(for: selectedURLs.map(SelectionItem.make(for:)))
    }

    /// 多选取交集：只有支持所有选中项的 App 才显示。
    func applications(for items: [SelectionItem]) -> [ApplicationMenuOption] {
        guard !items.isEmpty else { return [] }

        var matchingIDs: Set<String>?
        for item in items {
            let itemIDs = Set(applications(for: item).map(\.preferenceID))
            matchingIDs = matchingIDs.map { $0.intersection(itemIDs) } ?? itemIDs
            if matchingIDs?.isEmpty == true { return [] }
        }

        guard let matchingIDs else { return [] }
        return allApplications.filter { matchingIDs.contains($0.preferenceID) }
    }

    // MARK: - 单个选中项

    private func applications(for item: SelectionItem) -> [ApplicationMenuOption] {
        if item.isDirectory {
            return item.isPackage ? packageApplications(for: item) : directoryApplications
        }

        let fileExtension = item.filenameExtension
        if !fileExtension.isEmpty {
            // 有扩展名：先按扩展名快照；快照为空（.tsx、.go、.sh 等）才走兜底。
            if let snapshot = applicationsByExtension[fileExtension], !snapshot.isEmpty {
                return snapshot
            }
            return fallbackApplications(for: item)
        }

        // 无扩展名的文件（Makefile、Dockerfile、.gitignore）：只给编辑器类 App。
        return allApplications.filter(\.opensAnyFile)
    }

    /// 快照里没有这个扩展名时的兜底：符合声明 UTType 的 App，加上能打开任意文件的编辑器。
    private func fallbackApplications(for item: SelectionItem) -> [ApplicationMenuOption] {
        allApplications.filter { application in
            application.opensAnyFile
                || item.matchesAny(of: application.supportedTypeIdentifiers)
        }
    }

    /// 包（`.app`、`.rtfd`、`.xcodeproj` 等）单独处理（C-03）：
    /// 优先显示声明了该包类型的 App；否则交给能打开文件夹的 App（终端、编辑器、IDE）。
    private func packageApplications(for item: SelectionItem) -> [ApplicationMenuOption] {
        let conforming = allApplications.filter {
            item.matchesAny(of: $0.supportedTypeIdentifiers)
        }
        if !conforming.isEmpty { return conforming }
        if !directoryApplications.isEmpty { return directoryApplications }
        return allApplications.filter(\.isBundleOpener)
    }
}
