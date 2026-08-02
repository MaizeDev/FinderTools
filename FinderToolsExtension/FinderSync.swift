import AppKit
import FinderSync
import os

final class FinderSync: FIFinderSync {
    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderSync")
    private let preferences = UserDefaults.standard
    private var cachedConfiguration = MenuConfiguration.defaults
    private var allApplicationSnapshot: [ApplicationMenuOption] = []
    private var applicationSnapshots: [String: [ApplicationMenuOption]] = [:]
    private var directoryApplicationSnapshot: [ApplicationMenuOption] = []
    private var cachedMenuIcons: [String: NSImage] = [:]
    private var applicationTagByID: [String: Int] = [:]
    private var applicationPathByTag: [Int: String] = [:]

    override init() {
        super.init()

        if let data = preferences.data(forKey: PreferenceStorage.configuration),
           let configuration = try? JSONDecoder().decode(MenuConfiguration.self, from: data) {
            rebuildMenuSnapshots(using: configuration)
        } else {
            rebuildMenuSnapshots(using: .defaults)
        }

        let root = URL(fileURLWithPath: "/", isDirectory: true)
        FIFinderSyncController.default().directoryURLs = [root]

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receivePreferences(_:)),
            name: PreferenceNotification.update,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        DistributedNotificationCenter.default().post(
            name: PreferenceNotification.syncRequest,
            object: nil,
            userInfo: nil
        )
        logger.notice("FinderTools extension started; monitoring the Finder root directory")
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
            return makeCreateMenu()
        case .contextualMenuForItems:
            return makeOpenWithMenu()
        default:
            return nil
        }
    }

    private func makeCreateMenu() -> NSMenu? {
        guard FIFinderSyncController.default().targetedURL() != nil else {
            return nil
        }

        let configuration = cachedConfiguration
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

        primaryTypes.map(makeCreateMenuItem).forEach(menu.addItem)

        if !submenuTypes.isEmpty {
            let parentItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            parentItem.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: nil)
            let submenu = NSMenu(title: "新建文件")
            submenuTypes.map(makeCreateMenuItem).forEach(submenu.addItem)
            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        let terminalItem = NSMenuItem(
            title: "在终端中打开",
            action: #selector(openDirectoryInTerminal(_:)),
            keyEquivalent: ""
        )
        terminalItem.target = self
        terminalItem.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)
        menu.addItem(terminalItem)

        return menu
    }

    private func makeCreateMenuItem(for fileType: NewFileType) -> NSMenuItem {
        let item = NSMenuItem(title: fileType.menuTitle, action: #selector(createFile(_:)), keyEquivalent: "")
        item.target = self
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

    private func makeOpenWithMenu() -> NSMenu? {
        guard let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !selectedURLs.isEmpty else {
            return nil
        }

        let configuration = cachedConfiguration
        let applicationOptions = applicationsForSelection(selectedURLs)
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
            menu.addItem(makeApplicationMenuItem(option, isPrimary: true))
        }
        if hasPrimaryChooseOther {
            menu.addItem(makeChooseOtherMenuItem(isPrimary: true))
        }

        if !submenuOptions.isEmpty || hasSubmenuChooseOther {
            let parentItem = NSMenuItem(title: "使用软件打开", action: nil, keyEquivalent: "")
            parentItem.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: nil)
            let submenu = NSMenu(title: "使用软件打开")

            for option in submenuOptions {
                submenu.addItem(makeApplicationMenuItem(option, isPrimary: false))
            }
            if hasSubmenuChooseOther {
                if !submenuOptions.isEmpty {
                    submenu.addItem(.separator())
                }
                submenu.addItem(makeChooseOtherMenuItem(isPrimary: false))
            }

            parentItem.submenu = submenu
            menu.addItem(parentItem)
        }

        return menu
    }

    private func makeApplicationMenuItem(
        _ option: ApplicationMenuOption,
        isPrimary: Bool
    ) -> NSMenuItem {
        let title = isPrimary ? "使用\(option.name)打开" : option.name
        let item = NSMenuItem(
            title: title,
            action: #selector(openWithApplication(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.tag = applicationTagByID[option.preferenceID] ?? -1
        item.image = cachedMenuIcons[option.preferenceID] ?? option.fallbackMenuIcon
        item.image?.size = NSSize(width: 18, height: 18)
        return item
    }

    private func makeChooseOtherMenuItem(isPrimary: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: isPrimary ? "选择其他软件打开…" : "选择其他软件…",
            action: #selector(chooseOtherApplication(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = NSImage(systemSymbolName: "plus.app", accessibilityDescription: nil)
        return item
    }

    private func rebuildMenuSnapshots(using configuration: MenuConfiguration) {
        cachedConfiguration = configuration
        let enabledApplications = (configuration.applicationOptions ?? ApplicationMenuOption.defaults)
            .filter {
                configuration.applicationSetting(for: $0.preferenceID).isEnabled
            }

        allApplicationSnapshot = enabledApplications
        applicationSnapshots = [:]
        directoryApplicationSnapshot = enabledApplications.filter { $0.opensDirectories == true }
        cachedMenuIcons = [:]
        applicationTagByID = [:]
        applicationPathByTag = [:]

        for (tag, application) in enabledApplications.enumerated() {
            applicationTagByID[application.preferenceID] = tag
            applicationPathByTag[tag] = application.path

            for fileExtension in application.supportedExtensions ?? [] {
                applicationSnapshots[fileExtension.lowercased(), default: []].append(application)
            }

            let icon = application.menuIconData.flatMap(NSImage.init(data:))
                ?? application.fallbackMenuIcon
            icon?.size = NSSize(width: 18, height: 18)
            cachedMenuIcons[application.preferenceID] = icon
        }

        logger.notice(
            "Prepared \(enabledApplications.count, privacy: .public) enabled app menu entries and \(self.applicationSnapshots.count, privacy: .public) file-type snapshots"
        )
    }

    private func applicationsForSelection(_ selectedURLs: [URL]) -> [ApplicationMenuOption] {
        if selectedURLs.allSatisfy(\.hasDirectoryPath) {
            return directoryApplicationSnapshot
        }

        let selectedExtensions = Set(
            selectedURLs.map { $0.pathExtension.lowercased() }.filter { !$0.isEmpty }
        )
        guard !selectedExtensions.isEmpty else {
            return allApplicationSnapshot
        }

        if selectedExtensions.count == 1,
           let fileExtension = selectedExtensions.first {
            return applicationSnapshots[fileExtension] ?? []
        }

        return allApplicationSnapshot.filter { application in
            let supportedExtensions = Set(application.supportedExtensions ?? [])
            return selectedExtensions.isSubset(of: supportedExtensions)
        }
    }

    @objc private func receivePreferences(_ notification: Notification) {
        guard let encoded = notification.object as? String,
              let data = Data(base64Encoded: encoded),
              let configuration = try? JSONDecoder().decode(MenuConfiguration.self, from: data) else {
            logger.error("Ignored an invalid menu preferences update")
            return
        }

        preferences.set(data, forKey: PreferenceStorage.configuration)
        rebuildMenuSnapshots(using: configuration)
        logger.notice("Updated Finder menu preferences")
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        logger.notice("Create-file menu action received; tag=\(sender.tag, privacy: .public)")

        guard let fileType = NewFileType(rawValue: sender.tag) else {
            logger.error("Create-file action had an unknown tag")
            return
        }
        guard let directoryURL = FIFinderSyncController.default().targetedURL() else {
            logger.error("Finder did not provide a target directory for create-file action")
            return
        }

        sendCommand(
            action: "create",
            queryItems: [
                URLQueryItem(name: "directory", value: directoryURL.path),
                URLQueryItem(name: "type", value: fileType.fileExtension)
            ]
        )
    }

    @objc private func openDirectoryInTerminal(_ sender: NSMenuItem) {
        logger.notice("Open-in-terminal menu action received")

        guard let directoryURL = FIFinderSyncController.default().targetedURL() else {
            logger.error("Finder did not provide a target directory for open-in-terminal action")
            return
        }

        sendCommand(
            action: "terminal",
            queryItems: [URLQueryItem(name: "directory", value: directoryURL.path)]
        )
    }

    @objc private func openWithApplication(_ sender: NSMenuItem) {
        logger.notice("Open-with menu action received; tag=\(sender.tag, privacy: .public)")

        guard let applicationPath = applicationPathByTag[sender.tag],
              FileManager.default.fileExists(atPath: applicationPath) else {
            logger.error("Open-with action had an unavailable application path")
            return
        }
        guard let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !selectedURLs.isEmpty else {
            logger.error("Finder did not provide selected items for open-with action")
            return
        }

        sendOpenCommand(selectedURLs, applicationPath: applicationPath)
    }

    @objc private func chooseOtherApplication(_ sender: NSMenuItem) {
        logger.notice("Choose-other-application menu action received")

        guard let selectedURLs = FIFinderSyncController.default().selectedItemURLs(),
              !selectedURLs.isEmpty else {
            logger.error("Finder did not provide selected items for choose-other action")
            return
        }

        sendCommand(
            action: "choose",
            queryItems: selectedURLs.map { URLQueryItem(name: "item", value: $0.path) }
        )
    }

    private func sendOpenCommand(_ itemURLs: [URL], applicationPath: String) {
        var queryItems = [URLQueryItem(name: "application", value: applicationPath)]
        queryItems.append(contentsOf: itemURLs.map { URLQueryItem(name: "item", value: $0.path) })
        sendCommand(action: "open", queryItems: queryItems)
    }

    private func sendCommand(action: String, queryItems: [URLQueryItem]) {
        var components = URLComponents()
        components.scheme = "findertools"
        components.host = action
        components.queryItems = queryItems

        guard let commandURL = components.url else {
            logger.error("Could not send Finder action to the main app")
            return
        }

        let mainAppIsRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.wheat.FinderTools"
        ).isEmpty
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.hides = !mainAppIsRunning

        NSWorkspace.shared.open(commandURL, configuration: configuration) { [logger] _, error in
            if let error {
                logger.error("Could not send Finder action to the main app: \(error.localizedDescription, privacy: .public)")
            }
        }
        logger.notice("Sent Finder action to the main app: \(action, privacy: .public)")
    }
}

private enum NewFileType: Int, CaseIterable {
    case text
    case word
    case excel
    case powerPoint
    case markdown
    case richText
    case csv
    case json
    case yaml
    case html
    case css
    case javaScript
    case swift
    case python

    var preferenceID: String {
        switch self {
        case .text: "text"
        case .word: "word"
        case .excel: "excel"
        case .powerPoint: "powerpoint"
        case .markdown: "markdown"
        case .richText: "richtext"
        case .csv: "csv"
        case .json: "json"
        case .yaml: "yaml"
        case .html: "html"
        case .css: "css"
        case .javaScript: "javascript"
        case .swift: "swift"
        case .python: "python"
        }
    }

    var menuTitle: String {
        switch self {
        case .text: "未命名.txt"
        case .word: "未命名.docx"
        case .excel: "未命名.xlsx"
        case .powerPoint: "未命名.pptx"
        case .markdown: "未命名.md"
        case .richText: "未命名.rtf"
        case .csv: "未命名.csv"
        case .json: "未命名.json"
        case .yaml: "未命名.yaml"
        case .html: "未命名.html"
        case .css: "未命名.css"
        case .javaScript: "未命名.js"
        case .swift: "未命名.swift"
        case .python: "未命名.py"
        }
    }

    var fileExtension: String {
        switch self {
        case .text: "txt"
        case .word: "docx"
        case .excel: "xlsx"
        case .powerPoint: "pptx"
        case .markdown: "md"
        case .richText: "rtf"
        case .csv: "csv"
        case .json: "json"
        case .yaml: "yaml"
        case .html: "html"
        case .css: "css"
        case .javaScript: "js"
        case .swift: "swift"
        case .python: "py"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "doc.plaintext"
        case .word: "doc.text"
        case .excel: "tablecells"
        case .powerPoint: "rectangle.on.rectangle.angled"
        case .markdown: "text.document"
        case .richText: "doc.richtext"
        case .csv: "tablecells.badge.ellipsis"
        case .json: "curlybraces"
        case .yaml: "list.bullet.rectangle"
        case .html: "globe"
        case .css: "paintbrush"
        case .javaScript: "curlybraces.square"
        case .swift: "swift"
        case .python: "chevron.left.forwardslash.chevron.right"
        }
    }

    var menuColor: NSColor {
        switch self {
        case .text: .systemGray
        case .word: .systemBlue
        case .excel: .systemGreen
        case .powerPoint: .systemRed
        case .markdown: .systemIndigo
        case .richText: .systemPurple
        case .csv: .systemTeal
        case .json: .systemOrange
        case .yaml: .systemPink
        case .html: .systemBlue
        case .css: .systemCyan
        case .javaScript: .systemYellow
        case .swift: .systemOrange
        case .python: .systemBlue
        }
    }
}

private struct ApplicationMenuOption: Codable {
    let preferenceID: String
    let name: String
    let path: String
    let fallbackSymbol: String
    let isEnabledByDefault: Bool?
    let supportedExtensions: [String]?
    let opensDirectories: Bool?
    let menuIconData: Data?

    init(
        preferenceID: String,
        name: String,
        path: String,
        fallbackSymbol: String,
        isEnabledByDefault: Bool? = true,
        supportedExtensions: [String]? = nil,
        opensDirectories: Bool? = nil,
        menuIconData: Data? = nil
    ) {
        self.preferenceID = preferenceID
        self.name = name
        self.path = path
        self.fallbackSymbol = fallbackSymbol
        self.isEnabledByDefault = isEnabledByDefault
        self.supportedExtensions = supportedExtensions
        self.opensDirectories = opensDirectories
        self.menuIconData = menuIconData
    }

    var fallbackMenuIcon: NSImage? {
        NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: name)
    }

    static let defaults = [
        ApplicationMenuOption(preferenceID: "textedit", name: "文本编辑", path: "/System/Applications/TextEdit.app", fallbackSymbol: "doc.text"),
        ApplicationMenuOption(preferenceID: "preview", name: "预览", path: "/System/Applications/Preview.app", fallbackSymbol: "doc.richtext"),
        ApplicationMenuOption(preferenceID: "terminal", name: "终端", path: "/System/Applications/Utilities/Terminal.app", fallbackSymbol: "terminal"),
        ApplicationMenuOption(preferenceID: "iterm", name: "iTerm", path: "/Applications/iTerm.app", fallbackSymbol: "terminal"),
        ApplicationMenuOption(preferenceID: "vscode", name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", fallbackSymbol: "chevron.left.forwardslash.chevron.right"),
        ApplicationMenuOption(preferenceID: "cursor", name: "Cursor", path: "/Applications/Cursor.app", fallbackSymbol: "cursorarrow"),
        ApplicationMenuOption(preferenceID: "sublime", name: "Sublime Text", path: "/Applications/Sublime Text.app", fallbackSymbol: "text.alignleft"),
        ApplicationMenuOption(preferenceID: "bbedit", name: "BBEdit", path: "/Applications/BBEdit.app", fallbackSymbol: "pencil"),
        ApplicationMenuOption(preferenceID: "typora", name: "Typora", path: "/Applications/Typora.app", fallbackSymbol: "textformat"),
        ApplicationMenuOption(preferenceID: "iina", name: "IINA", path: "/Applications/IINA.app", fallbackSymbol: "play.rectangle"),
        ApplicationMenuOption(preferenceID: "word", name: "Microsoft Word", path: "/Applications/Microsoft Word.app", fallbackSymbol: "doc.text"),
        ApplicationMenuOption(preferenceID: "excel", name: "Microsoft Excel", path: "/Applications/Microsoft Excel.app", fallbackSymbol: "tablecells"),
        ApplicationMenuOption(preferenceID: "powerpoint", name: "Microsoft PowerPoint", path: "/Applications/Microsoft PowerPoint.app", fallbackSymbol: "rectangle.on.rectangle.angled"),
        ApplicationMenuOption(preferenceID: "xcode", name: "Xcode", path: "/Applications/Xcode.app", fallbackSymbol: "hammer")
    ]
}

private enum MenuPlacement: String, Codable {
    case primary
    case submenu
}

private struct MenuItemSetting: Codable {
    let isEnabled: Bool
    let placement: MenuPlacement

    static let defaults = MenuItemSetting(isEnabled: true, placement: .submenu)
}

private struct MenuConfiguration: Codable {
    let newFiles: [String: MenuItemSetting]
    let applications: [String: MenuItemSetting]
    let applicationOptions: [ApplicationMenuOption]?

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

    static let defaults = MenuConfiguration(
        newFiles: [:],
        applications: [:],
        applicationOptions: nil
    )
}

private enum PreferenceStorage {
    static let configuration = "menuConfiguration"
}

private enum PreferenceNotification {
    static let update = Notification.Name("com.wheat.FinderTools.menuPreferencesDidChange")
    static let syncRequest = Notification.Name("com.wheat.FinderTools.menuPreferencesSyncRequest")
}
