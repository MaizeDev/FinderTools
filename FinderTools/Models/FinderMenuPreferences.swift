import Foundation
import os

enum FinderMenuPreferences {
    static let store = UserDefaults.standard

    private static let logger = Logger(
        subsystem: "com.wheat.FinderTools",
        category: "MenuPreferences"
    )

    /// C-06：短时间内的多次设置变更合并成一次广播（尾随去抖）。
    private static let broadcastDebounceDelay = Duration.milliseconds(300)

    static let newFileDefaults: [(id: String, isEnabled: Bool)] =
        NewFileType.allCases.map { ($0.preferenceID, $0.isEnabledByDefault) }

    private static let applicationCatalogKey = "installedApplicationCatalog"
    private static let applicationCatalogRefreshDateKey = "installedApplicationCatalogRefreshDate"

    private static var syncRequestObserver: NSObjectProtocol?
    private static var pendingBroadcastTask: Task<Void, Never>?
    private static var hasPendingSettings = false
    private static var pendingCatalogData: Data?

    static func enabledKey(group: String, id: String) -> String {
        "menu.\(group).\(id).enabled"
    }

    static func placementKey(group: String, id: String) -> String {
        "menu.\(group).\(id).placement"
    }

    static func startSyncingWithExtension() {
        guard syncRequestObserver == nil else { return }

        syncRequestObserver = DistributedNotificationCenter.default().addObserver(
            forName: MenuNotificationName.syncRequest,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                broadcastConfiguration()
            }
        }

        broadcastConfiguration()
    }

    /// 设置页里拨开关时调用：0.3 秒内的多次变更合并成一条小负载广播（C-06）。
    static func notifyExtension() {
        scheduleBroadcast(settingsChanged: true, catalogData: nil)
    }

    static func updateApplications(_ applications: [ApplicationMenuOption]) {
        guard let data = try? JSONEncoder().encode(applications) else { return }
        let previousData = store.data(forKey: applicationCatalogKey)
        store.set(data, forKey: applicationCatalogKey)
        store.set(Date(), forKey: applicationCatalogRefreshDateKey)

        // 目录没有变化就不广播（后台扫描每次启动都会跑一次）；有变化时设置段的
        // 应用默认值集合也一起变，所以两段一起发。这里直接复用刚编码好的目录
        // JSON，避免第二次编码（C-06）。
        guard data != previousData else { return }
        scheduleBroadcast(settingsChanged: true, catalogData: data)
    }

    static var installedApplications: [ApplicationMenuOption] {
        storedApplications
    }

    /// 已启用的“打开方式”应用，是 `findertools://open` 校验时“已启用应用目录”的单一来源。
    /// `choose` 流程从 `NSOpenPanel` 选 App，不受这份名单限制。
    static var enabledApplications: [ApplicationMenuOption] {
        let applications = storedApplications
        let applicationSettings = settings(
            group: "application",
            defaults: applications.map { ($0.preferenceID, $0.isEnabledByDefault) }
        )
        return applications.filter { applicationSettings[$0.preferenceID]?.isEnabled == true }
    }

    static var applicationCatalogRefreshDate: Date? {
        store.object(forKey: applicationCatalogRefreshDateKey) as? Date
    }

    /// C-06 的设置段：`newFiles` + 所有已知应用的设置（含被关闭的应用）。
    ///
    /// 必须包含被关闭的应用：拆分后扩展手里有完整的应用目录（含图标），
    /// 它靠这份设置判断每个 App 是否显示；缺项会被 `applicationSetting(for:)`
    /// 当成“旧配置没有这一项”回退到默认值，导致已关闭的精选 App 又冒出来。
    private static var settingsConfiguration: MenuConfiguration {
        let applications = storedApplications
        let applicationSettings = settings(
            group: "application",
            defaults: applications.map { ($0.preferenceID, $0.isEnabledByDefault) }
                + [("other", true)]
        )

        return MenuConfiguration(
            newFiles: settings(group: "newFile", defaults: newFileDefaults),
            applications: applicationSettings,
            applicationOptions: nil,
            // C-05：扩展靠这份路径设置 `directoryURLs`。没授权文件夹时发送空数组，
            // 扩展据此关闭所有位置的菜单（与旧数据的 `nil` 区分开）。
            authorizedFolderPaths: FolderAccessManager.shared.authorizedFolderPaths
        )
    }

    private static var storedApplications: [ApplicationMenuOption] {
        guard let data = store.data(forKey: applicationCatalogKey),
              let applications = try? JSONDecoder().decode([ApplicationMenuOption].self, from: data) else {
            return []
        }
        return applications
    }

    private static func settings(
        group: String,
        defaults: [(id: String, isEnabled: Bool)]
    ) -> [String: MenuItemSetting] {
        // D-08：同一 id 出现多次时保留第一个，避免 `uniqueKeysWithValues` 崩溃。
        // 设置值只由 id 决定，重复项的取值本来也相同。
        Dictionary(
            defaults.map { id, defaultEnabled in
                let enabledKey = enabledKey(group: group, id: id)
                let placementKey = placementKey(group: group, id: id)
                let isEnabled = store.object(forKey: enabledKey) == nil
                    ? defaultEnabled
                    : store.bool(forKey: enabledKey)
                let placement = store.string(forKey: placementKey)
                    .flatMap(MenuPlacement.init(rawValue:)) ?? .submenu

                return (id, MenuItemSetting(isEnabled: isEnabled, placement: placement))
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    // MARK: - 广播（C-06）

    /// 启动 / syncRequest：立即补发完整状态（设置段 + 应用目录段）。
    ///
    /// 冷启动（Finder 右键拉起）时扩展可能刚请求过配置但主 App 还没运行，
    /// 所以这里两段都补发一次。不再发旧版整份配置：升级前就在运行的旧扩展
    /// 进程只认旧通知名，重启 Finder 后加载新扩展即恢复（验收清单写明）。
    private static func broadcastConfiguration() {
        pendingBroadcastTask?.cancel()
        pendingBroadcastTask = nil
        hasPendingSettings = false
        pendingCatalogData = nil

        postSettings()
        if let catalogData = store.data(forKey: applicationCatalogKey) {
            postApplicationCatalog(catalogData)
        }
    }

    private static func scheduleBroadcast(settingsChanged: Bool, catalogData: Data?) {
        if settingsChanged {
            hasPendingSettings = true
        }
        if let catalogData {
            pendingCatalogData = catalogData
        }

        pendingBroadcastTask?.cancel()
        pendingBroadcastTask = Task { @MainActor in
            try? await Task.sleep(for: broadcastDebounceDelay)
            guard !Task.isCancelled else { return }
            flushPendingBroadcast()
        }
    }

    private static func flushPendingBroadcast() {
        guard hasPendingSettings || pendingCatalogData != nil else { return }

        let shouldSendSettings = hasPendingSettings
        let catalogData = pendingCatalogData
        hasPendingSettings = false
        pendingCatalogData = nil
        pendingBroadcastTask = nil

        if shouldSendSettings {
            postSettings()
        }
        if let catalogData {
            postApplicationCatalog(catalogData)
        }
    }

    private static func postSettings() {
        let settings = settingsConfiguration
        guard let data = try? JSONEncoder().encode(settings) else {
            logger.error("Failed to encode menu settings")
            return
        }

        let encoded = data.base64EncodedString()
        logger.notice(
            "Broadcast menu settings: json=\(data.count, privacy: .public) bytes, base64=\(encoded.count, privacy: .public) chars"
        )
        DistributedNotificationCenter.default().post(
            name: MenuNotificationName.settings,
            object: encoded,
            userInfo: nil
        )
    }

    private static func postApplicationCatalog(_ data: Data) {
        let encoded = data.base64EncodedString()
        logger.notice(
            "Broadcast application catalog: json=\(data.count, privacy: .public) bytes, base64=\(encoded.count, privacy: .public) chars"
        )
        DistributedNotificationCenter.default().post(
            name: MenuNotificationName.applicationCatalog,
            object: encoded,
            userInfo: nil
        )
    }
}
