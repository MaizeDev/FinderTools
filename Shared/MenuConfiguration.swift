import Foundation

/// 菜单项显示位置。rawValue 是持久化值，不能改。
nonisolated enum MenuPlacement: String, CaseIterable, Identifiable, Codable, Sendable {
    case primary
    case submenu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .primary: "一级菜单"
        case .submenu: "二级菜单"
        }
    }
}

/// 单个菜单项的设置。JSON 键 `isEnabled` / `placement` 不能改。
nonisolated struct MenuItemSetting: Codable, Sendable {
    let isEnabled: Bool
    let placement: MenuPlacement

    static let defaults = MenuItemSetting(isEnabled: true, placement: .submenu)

    init(isEnabled: Bool, placement: MenuPlacement) {
        self.isEnabled = isEnabled
        self.placement = placement
    }
}

/// 主 App 广播给扩展的整份菜单配置。JSON 键 `newFiles` / `applications` /
/// `applicationOptions` 不能改。
nonisolated struct MenuConfiguration: Codable, Sendable {
    let newFiles: [String: MenuItemSetting]
    let applications: [String: MenuItemSetting]
    let applicationOptions: [ApplicationMenuOption]?

    /// 已授权文件夹的路径。
    ///
    /// 第 19 步起扩展不再使用这个字段：右键菜单始终显示，主 App 在真正执行操作时才
    /// 请求文件夹授权。字段仍保留是为了解码旧缓存、升级与回滚兼容，JSON 键名不能改。
    /// 新版主 App 仍然会发送它，让升级期间还在运行的旧扩展进程继续按旧语义工作；
    /// 新扩展会忽略它（见 `FinderSync.monitorRootDirectory()`）。
    let authorizedFolderPaths: [String]?

    init(
        newFiles: [String: MenuItemSetting],
        applications: [String: MenuItemSetting],
        applicationOptions: [ApplicationMenuOption]?,
        authorizedFolderPaths: [String]? = nil
    ) {
        self.newFiles = newFiles
        self.applications = applications
        self.applicationOptions = applicationOptions
        self.authorizedFolderPaths = authorizedFolderPaths
    }

    func newFileSetting(for id: String) -> MenuItemSetting {
        if let setting = newFiles[id] {
            return setting
        }
        let originalFileTypes = ["text", "word", "excel", "powerpoint"]
        return MenuItemSetting(
            isEnabled: originalFileTypes.contains(id),
            placement: .submenu
        )
    }

    func applicationSetting(for id: String) -> MenuItemSetting {
        if let setting = applications[id] {
            return setting
        }
        let originalApplicationIDs = Set(
            ApplicationMenuOption.defaults.map(\.preferenceID) + ["other"]
        )
        return MenuItemSetting(
            isEnabled: originalApplicationIDs.contains(id),
            placement: .submenu
        )
    }

    /// C-06：设置段（不含应用目录/图标）。编码后的 JSON 键仍是 `newFiles` /
    /// `applications`，与旧版整份配置的对应字段完全一致。
    /// 第 19 步：授权文件夹路径只是随设置段原样保留（编码/解码兼容），扩展不再使用。
    func removingApplicationOptions() -> MenuConfiguration {
        MenuConfiguration(
            newFiles: newFiles,
            applications: applications,
            applicationOptions: nil,
            authorizedFolderPaths: authorizedFolderPaths
        )
    }

    /// C-06：把设置段和最新的应用目录合并回 `MenuBuilder` 认识的整份配置。
    func merging(applicationOptions: [ApplicationMenuOption]?) -> MenuConfiguration {
        MenuConfiguration(
            newFiles: newFiles,
            applications: applications,
            applicationOptions: applicationOptions,
            authorizedFolderPaths: authorizedFolderPaths
        )
    }

    static let defaults = MenuConfiguration(
        newFiles: [:],
        applications: [:],
        applicationOptions: nil
    )
}

/// 主 App 的 Bundle Identifier。扩展用它在 `menu(for:)` 里判断主 App 是否在运行；
/// 必须与 FinderTools target 的 `PRODUCT_BUNDLE_IDENTIFIER` 保持一致。
nonisolated enum FinderToolsBundleIdentifier {
    static let mainApp = "com.wheat.FinderTools"
}

/// 主 App 与扩展之间的通知名（C-06）。两边共用一份，避免字符串在两处维护。
nonisolated enum MenuNotificationName {
    /// 旧协议：整份配置（设置 + 应用目录含图标）。C-06 之后只在启动 /
    /// syncRequest 时补发一次，用来兼容升级前已运行的旧扩展进程和回滚。
    static let legacyConfiguration = Notification.Name(
        "com.wheat.FinderTools.menuPreferencesDidChange"
    )

    /// 设置段：`newFiles` / `applications`，不含图标。开关变更只发这一条。
    static let settings = Notification.Name(
        "com.wheat.FinderTools.menuSettingsDidChange"
    )

    /// 应用目录段：已启用 App 的完整列表（含 36px PNG 图标）。只在目录刷新后发。
    static let applicationCatalog = Notification.Name(
        "com.wheat.FinderTools.applicationCatalogDidChange"
    )

    /// 扩展启动时请求主 App 重发配置。
    static let syncRequest = Notification.Name(
        "com.wheat.FinderTools.menuPreferencesSyncRequest"
    )
}
