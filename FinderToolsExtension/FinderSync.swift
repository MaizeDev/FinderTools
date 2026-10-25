import AppKit
import FinderSync
import os

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderSync")
    private let commands = CommandSender()
    private let configurationStore = ExtensionConfigurationStore()
    private var menuBuilder: MenuBuilder

    override init() {
        menuBuilder = MenuBuilder(configuration: configurationStore.mergedConfiguration)

        super.init()

        // C-05：只监听主 App 广播的授权文件夹；缓存里还没有路径字段时沿用旧行为（监听 `/`）。
        applyDirectoryURLs(from: configurationStore.mergedConfiguration)

        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(receiveSettings(_:)),
            name: MenuNotificationName.settings,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        center.addObserver(
            self,
            selector: #selector(receiveApplicationCatalog(_:)),
            name: MenuNotificationName.applicationCatalog,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        // 旧协议（整份配置）：升级前就在运行的旧主 App、或回滚后的旧版本会发这条。
        center.addObserver(
            self,
            selector: #selector(receiveLegacyConfiguration(_:)),
            name: MenuNotificationName.legacyConfiguration,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        center.post(
            name: MenuNotificationName.syncRequest,
            object: nil,
            userInfo: nil
        )
        logger.notice(
            "FinderTools extension started; monitoring \(FIFinderSyncController.default().directoryURLs.count, privacy: .public) authorized folder(s)"
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let startTime = ProcessInfo.processInfo.systemUptime
        defer {
            let elapsedMilliseconds = (ProcessInfo.processInfo.systemUptime - startTime) * 1_000
            logger.debug(
                "Built Finder menu kind \(menuKind.rawValue, privacy: .public) in \(elapsedMilliseconds, format: .fixed(precision: 2)) ms"
            )
        }
        logger.debug("Finder requested menu kind: \(menuKind.rawValue, privacy: .public)")
        switch menuKind {
        case .contextualMenuForContainer:
            return menuBuilder.makeCreateMenu(
                targetedURL: FIFinderSyncController.default().targetedURL(),
                target: self
            )
        case .contextualMenuForItems:
            return menuBuilder.makeOpenWithMenu(
                selectedURLs: FIFinderSyncController.default().selectedItemURLs(),
                target: self
            )
        default:
            return nil
        }
    }

    // MARK: - 配置更新（C-06）

    @objc private func receiveSettings(_ notification: Notification) {
        guard let configuration = decode(MenuConfiguration.self, from: notification) else {
            return
        }

        configurationStore.updateSettings(from: configuration)
        applyDirectoryURLs(from: configuration)
        rebuildMenu()
        logger.notice("Updated Finder menu settings")
    }

    @objc private func receiveApplicationCatalog(_ notification: Notification) {
        guard let data = payloadData(from: notification),
              let applications = try? JSONDecoder().decode([ApplicationMenuOption].self, from: data) else {
            logger.error("Ignored an invalid application catalog update")
            return
        }

        configurationStore.updateApplicationOptions(applications, encodedData: data)
        rebuildMenu()
        logger.notice(
            "Updated the application catalog: \(applications.count, privacy: .public) entries"
        )
    }

    @objc private func receiveLegacyConfiguration(_ notification: Notification) {
        guard let data = payloadData(from: notification),
              let configuration = try? JSONDecoder().decode(MenuConfiguration.self, from: data) else {
            logger.error("Ignored an invalid legacy menu configuration")
            return
        }

        configurationStore.adoptLegacyConfiguration(configuration, encodedData: data)
        // 旧协议没有授权文件夹字段（nil），按兼容规则暂时回退到监听 `/`。
        applyDirectoryURLs(from: configuration)
        rebuildMenu()
        logger.notice("Adopted a full menu configuration from the pre-split protocol")
    }

    private func rebuildMenu() {
        menuBuilder = MenuBuilder(configuration: configurationStore.mergedConfiguration)
    }

    // MARK: - 目录监听（C-05）

    /// 按配置里的授权文件夹设置扩展的监听范围。
    ///
    /// - `authorizedFolderPaths == nil`：旧版配置或升级前的缓存还没有这个字段，
    ///   暂时沿用旧行为监听 `/`；主 App 升级后第一次广播就会收敛到真实授权列表。
    /// - `authorizedFolderPaths == []`：新版主 App 明确表示没有任何授权文件夹，
    ///   按 SDK 文档把 `directoryURLs` 设为空集合，任何位置都不出现菜单。
    private func applyDirectoryURLs(from configuration: MenuConfiguration) {
        let desiredURLs: Set<URL>
        if let folderPaths = configuration.authorizedFolderPaths {
            desiredURLs = Set(folderPaths.map { URL(fileURLWithPath: $0, isDirectory: true) })
        } else {
            desiredURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
        }

        let controller = FIFinderSyncController.default()
        if let currentURLs = controller.directoryURLs, currentURLs == desiredURLs {
            return
        }
        controller.directoryURLs = desiredURLs

        if desiredURLs.isEmpty {
            logger.notice("No authorized folders; the Finder menu stays hidden until a folder is authorized")
        } else {
            logger.notice(
                "Updating Finder directory monitoring: \(desiredURLs.count, privacy: .public) folder(s)"
            )
        }
    }

    private func payloadData(from notification: Notification) -> Data? {
        guard let encoded = notification.object as? String,
              let data = Data(base64Encoded: encoded) else {
            logger.error("Ignored a malformed menu preferences payload")
            return nil
        }
        return data
    }

    private func decode<Value: Decodable>(
        _ type: Value.Type,
        from notification: Notification
    ) -> Value? {
        guard let data = payloadData(from: notification) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Ignored a menu preferences payload that failed to decode")
            return nil
        }
    }

    // MARK: - 菜单动作

    @objc func createFile(_ sender: NSMenuItem) {
        logger.notice("Create-file menu action received; tag=\(sender.tag, privacy: .public)")

        guard let fileType = NewFileType(rawValue: sender.tag) else {
            logger.error("Create-file action had an unknown tag")
            return
        }
        guard let directoryURL = FIFinderSyncController.default().targetedURL() else {
            logger.error("Finder did not provide a target directory for create-file action")
            return
        }

        commands.createFile(in: directoryURL, fileExtension: fileType.fileExtension)
    }

    @objc func openDirectoryInTerminal(_ sender: NSMenuItem) {
        logger.notice("Open-in-terminal menu action received")

        guard let directoryURL = FIFinderSyncController.default().targetedURL() else {
            logger.error("Finder did not provide a target directory for open-in-terminal action")
            return
        }

        commands.openInTerminal(directoryURL: directoryURL)
    }

    @objc func openWithApplication(_ sender: NSMenuItem) {
        logger.notice("Open-with menu action received; tag=\(sender.tag, privacy: .public)")

        guard let applicationPath = menuBuilder.applicationPath(forTag: sender.tag),
              FileManager.default.fileExists(atPath: applicationPath) else {
            logger.error("Open-with action had an unavailable application path")
            return
        }
        guard let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !selectedURLs.isEmpty else {
            logger.error("Finder did not provide selected items for open-with action")
            return
        }

        commands.open(items: selectedURLs, applicationPath: applicationPath)
    }

    @objc func chooseOtherApplication(_ sender: NSMenuItem) {
        logger.notice("Choose-other-application menu action received")

        guard let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !selectedURLs.isEmpty else {
            logger.error("Finder did not provide selected items for choose-other action")
            return
        }

        commands.chooseOther(items: selectedURLs)
    }
}
