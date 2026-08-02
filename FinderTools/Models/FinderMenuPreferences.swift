import Foundation

enum FinderMenuPlacement: String, CaseIterable, Identifiable, Codable {
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

struct FinderMenuItemSetting: Codable {
    let isEnabled: Bool
    let placement: FinderMenuPlacement
}

struct FinderMenuConfiguration: Codable {
    let newFiles: [String: FinderMenuItemSetting]
    let applications: [String: FinderMenuItemSetting]
}

enum FinderMenuPreferences {
    static let store = UserDefaults.standard

    static let newFileIDs = ["text", "word", "excel", "powerpoint"]
    static let applicationIDs = [
        "textedit", "preview", "terminal", "iterm", "vscode", "cursor",
        "sublime", "bbedit", "typora", "iina", "word", "excel",
        "powerpoint", "xcode", "other"
    ]

    private static let updateNotification = Notification.Name(
        "com.wheat.FinderTools.menuPreferencesDidChange"
    )
    private static let syncRequestNotification = Notification.Name(
        "com.wheat.FinderTools.menuPreferencesSyncRequest"
    )
    private static var syncRequestObserver: NSObjectProtocol?

    static func enabledKey(group: String, id: String) -> String {
        "menu.\(group).\(id).enabled"
    }

    static func placementKey(group: String, id: String) -> String {
        "menu.\(group).\(id).placement"
    }

    static func startSyncingWithExtension() {
        guard syncRequestObserver == nil else { return }

        syncRequestObserver = DistributedNotificationCenter.default().addObserver(
            forName: syncRequestNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                notifyExtension()
            }
        }

        notifyExtension()
    }

    static func notifyExtension() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }

        DistributedNotificationCenter.default().post(
            name: updateNotification,
            object: data.base64EncodedString(),
            userInfo: nil
        )
    }

    private static var configuration: FinderMenuConfiguration {
        FinderMenuConfiguration(
            newFiles: settings(group: "newFile", ids: newFileIDs),
            applications: settings(group: "application", ids: applicationIDs)
        )
    }

    private static func settings(
        group: String,
        ids: [String]
    ) -> [String: FinderMenuItemSetting] {
        Dictionary(uniqueKeysWithValues: ids.map { id in
            let enabledKey = enabledKey(group: group, id: id)
            let placementKey = placementKey(group: group, id: id)
            let isEnabled = store.object(forKey: enabledKey) == nil
                ? true
                : store.bool(forKey: enabledKey)
            let placement = store.string(forKey: placementKey)
                .flatMap(FinderMenuPlacement.init(rawValue:)) ?? .submenu

            return (id, FinderMenuItemSetting(isEnabled: isEnabled, placement: placement))
        })
    }
}
