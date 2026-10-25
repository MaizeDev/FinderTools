import AppKit
import os

/// 构建 Finder 右键菜单：吃一份 `MenuConfiguration`，在这里维护 App 快照、tag 和图标缓存（D-02）。
final class MenuBuilder {
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderSync")
    private let configuration: MenuConfiguration
    private let selectionMatcher: SelectionMatcher
    private let applicationTagByID: [String: Int]
    private let applicationPathByTag: [Int: String]
    private let cachedMenuIcons: [String: NSImage]

    init(configuration: MenuConfiguration) {
        self.configuration = configuration

        let enabledApplications = (configuration.applicationOptions ?? ApplicationMenuOption.defaults)
            .filter {
                configuration.applicationSetting(for: $0.preferenceID).isEnabled
            }

        var applicationsByExtension: [String: [ApplicationMenuOption]] = [:]
        var tagByID: [String: Int] = [:]
        var pathByTag: [Int: String] = [:]
        var icons: [String: NSImage] = [:]

        for (tag, application) in enabledApplications.enumerated() {
            tagByID[application.preferenceID] = tag
            pathByTag[tag] = application.path

            for fileExtension in application.supportedExtensions {
                applicationsByExtension[fileExtension.lowercased(), default: []].append(application)
            }

            let icon = application.menuIconData.flatMap(NSImage.init(data:))
                ?? application.fallbackMenuIcon
            icon?.size = NSSize(width: 18, height: 18)
            icons[application.preferenceID] = icon
        }

        selectionMatcher = SelectionMatcher(
            allApplications: enabledApplications,
            applicationsByExtension: applicationsByExtension,
            directoryApplications: enabledApplications.filter(\.opensDirectories)
        )
        applicationTagByID = tagByID
        applicationPathByTag = pathByTag
        cachedMenuIcons = icons

        logger.notice(
            "Prepared \(enabledApplications.count, privacy: .public) enabled app menu entries and \(applicationsByExtension.count, privacy: .public) file-type snapshots"
        )
    }

    func applicationPath(forTag tag: Int) -> String? {
        applicationPathByTag[tag]
    }

    // MARK: - 新建文件菜单

    func makeCreateMenu(targetedURL: URL?, target: FinderSync) -> NSMenu? {
        guard targetedURL != nil else {
            return nil
        }

        let enabledTypes = NewFileType.allCases.filter {
            configuration.newFileSetting(for: $0.preferenceID).isEnabled
        }
        let primaryTypes = enabledTypes.filter {
            configuration.newFileSetting(for: $0.preferenceID).placement == .primary
        }
        let submenuTypes = enabledTypes.filter {
            configuration.newFileSetting(for: $0.preferenceID).placement == .submenu
        }
        let menu = NSMenu(title: "")

        primaryTypes.map { makeCreateMenuItem(for: $0, target: target) }.forEach(menu.addItem)

        if !submenuTypes.isEmpty {
            let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            parentItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            let submenu = NSMenu(title: "新建文件")
            submenuTypes.map { makeCreateMenuItem(for: $0, target: target) }.forEach(submenu.addItem)
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        let terminalItem = NSMenuItem(
            title: "在终端中打开",
            action: #selector(FinderSync.openDirectoryInTerminal(_:)),
            keyEquivalent: ""
        )
        terminalItem.target = target
        terminalItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        menu.addItem(terminalItem)

        return menu
    }

    private func makeCreateMenuItem(for fileType: NewFileType, target: FinderSync) -> NSMenuItem {
        let item = NSMenuItem(
            title: fileType.menuTitle,
            action: #selector(FinderSync.createFile(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.tag = fileType.rawValue
        let symbolConfiguration = NSImage.SymbolConfiguration(
            hierarchicalColor: fileType.menuColor
        )
        let icon = NSImage(
            systemSymbolName: fileType.systemImage,
            accessibilityDescription: nil
        )?.withSymbolConfiguration(symbolConfiguration)
        icon?.isTemplate = false
        item.image = icon
        return item
    }

    // MARK: - 使用软件打开菜单

    func makeOpenWithMenu(selectedURLs: [URL]?, target: FinderSync) -> NSMenu? {
        guard let selectedURLs, !selectedURLs.isEmpty else {
            return nil
        }

        let applicationOptions = selectionMatcher.applications(for: selectedURLs)
        let primaryOptions = applicationOptions.filter { option in
            configuration.applicationSetting(for: option.preferenceID).placement == .primary
        }
        let submenuOptions = applicationOptions.filter { option in
            configuration.applicationSetting(for: option.preferenceID).placement == .submenu
        }
        let chooseOtherSetting = configuration.applicationSetting(for: "other")
        let hasPrimaryChooseOther = chooseOtherSetting.isEnabled
            && chooseOtherSetting.placement == .primary
        let hasSubmenuChooseOther = chooseOtherSetting.isEnabled
            && chooseOtherSetting.placement == .submenu

        guard !primaryOptions.isEmpty
                || !submenuOptions.isEmpty
                || hasPrimaryChooseOther
                || hasSubmenuChooseOther else {
            return nil
        }

        let menu = NSMenu(title: "")

        for option in primaryOptions {
            menu.addItem(makeApplicationMenuItem(option, isPrimary: true, target: target))
        }
        if hasPrimaryChooseOther {
            menu.addItem(makeChooseOtherMenuItem(isPrimary: true, target: target))
        }

        if !submenuOptions.isEmpty || hasSubmenuChooseOther {
            let parentItem = NSMenuItem(title: "使用软件打开", action: nil, keyEquivalent: "")
            parentItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
            let submenu = NSMenu(title: "使用软件打开")

            for option in submenuOptions {
                submenu.addItem(makeApplicationMenuItem(option, isPrimary: false, target: target))
            }
            if hasSubmenuChooseOther {
                if !submenuOptions.isEmpty {
                    submenu.addItem(.separator())
                }
                submenu.addItem(makeChooseOtherMenuItem(isPrimary: false, target: target))
            }

            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        return menu
    }

    private func makeApplicationMenuItem(
        _ option: ApplicationMenuOption,
        isPrimary: Bool,
        target: FinderSync
    ) -> NSMenuItem {
        let title = isPrimary ? "使用\(option.name)打开" : option.name
        let item = NSMenuItem(
            title: title,
            action: #selector(FinderSync.openWithApplication(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.tag = applicationTagByID[option.preferenceID] ?? -1
        item.image = cachedMenuIcons[option.preferenceID] ?? option.fallbackMenuIcon
        item.image?.size = NSSize(width: 18, height: 18)
        return item
    }

    private func makeChooseOtherMenuItem(isPrimary: Bool, target: FinderSync) -> NSMenuItem {
        let item = NSMenuItem(
            title: isPrimary ? "选择其他软件打开…" : "选择其他软件…",
            action: #selector(FinderSync.chooseOtherApplication(_:)),
            keyEquivalent: ""
        )
        item.target = target
        item.image = NSImage(systemSymbolName: "plus.app", accessibilityDescription: nil)
        return item
    }
}
