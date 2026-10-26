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

        // 第 19 步：菜单始终显示，不再按授权文件夹收敛监听范围（回到 V1.1.1 之前监听 `/` 的做法）。
        // 授权改由主 App 在真正执行操作时请求。
        monitorRootDirectory()

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
        logger.notice("FinderTools extension started; the context menu is available in every folder")
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

        // 第 20 步：每次弹出菜单都实时判断主 App 是否在运行；不在运行就返回 nil，
        // 让 Finder 完全不显示 FinderTools 菜单。检查结果与耗时由该函数写 debug 日志。
        guard MainAppLiveness.isMainAppRunningForMenu() else {
            return nil
        }

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
        rebuildMenu()
        logger.notice("Adopted a full menu configuration from the pre-split protocol")
    }

    private func rebuildMenu() {
        menuBuilder = MenuBuilder(configuration: configurationStore.mergedConfiguration)
    }

    // MARK: - 目录监听（第 19 步）

    /// 固定监听根目录 `/`：右键菜单在任何位置都显示，授权改由主 App 在真正执行操作时请求。
    ///
    /// `MenuConfiguration.authorizedFolderPaths` 仍然保留解码（旧缓存 / 升级 / 回滚兼容），
    /// 但扩展不再用它设置 `directoryURLs`。原因：V1.1.1 的“菜单只出现在授权文件夹”语义
    /// 与 README 的“始终显示、用到时再授权”不一致，第 19 步按产品决定回退到旧做法。
    private func monitorRootDirectory() {
        let desiredURLs: Set<URL> = [URL(fileURLWithPath: "/", isDirectory: true)]

        let controller = FIFinderSyncController.default()
        guard controller.directoryURLs != desiredURLs else { return }
        controller.directoryURLs = desiredURLs
        logger.notice("Monitoring the root directory so the Finder menu is always available")
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
