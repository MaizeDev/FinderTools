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
    let applicationOptions: [ApplicationOption]
}

enum FinderMenuPreferences {
    static let store = UserDefaults.standard

    static let newFileDefaults: [(id: String, isEnabled: Bool)] = [
        ("text", true), ("word", true), ("excel", true), ("powerpoint", true),
        ("markdown", false), ("richtext", false), ("csv", false),
        ("json", false), ("yaml", false), ("html", false), ("css", false),
        ("javascript", false), ("swift", false), ("python", false)
    ]

    private static let applicationCatalogKey = "installedApplicationCatalog"
    private static let applicationCatalogRefreshDateKey = "installedApplicationCatalogRefreshDate"

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

    static func updateApplications(_ applications: [ApplicationOption]) {
        guard let data = try? JSONEncoder().encode(applications) else { return }
        store.set(data, forKey: applicationCatalogKey)
        store.set(Date(), forKey: applicationCatalogRefreshDateKey)
        notifyExtension()
    }

    static var installedApplications: [ApplicationOption] {
        storedApplications
    }

    static var applicationCatalogRefreshDate: Date? {
        store.object(forKey: applicationCatalogRefreshDateKey) as? Date
    }

    private static var configuration: FinderMenuConfiguration {
        let applications = storedApplications
        let allApplicationSettings = settings(
            group: "application",
            defaults: applications.map { ($0.preferenceID, $0.isEnabledByDefault) }
                + [("other", true)]
        )
        let enabledApplications = applications.filter {
            allApplicationSettings[$0.preferenceID]?.isEnabled == true
        }
        var enabledApplicationSettings = Dictionary(
            uniqueKeysWithValues: enabledApplications.compactMap { application in
                allApplicationSettings[application.preferenceID].map {
                    (application.preferenceID, $0)
                }
            }
        )
        enabledApplicationSettings["other"] = allApplicationSettings["other"]

        return FinderMenuConfiguration(
            newFiles: settings(group: "newFile", defaults: newFileDefaults),
            applications: enabledApplicationSettings,
            applicationOptions: enabledApplications
        )
    }

    private static var storedApplications: [ApplicationOption] {
        guard let data = store.data(forKey: applicationCatalogKey),
              let applications = try? JSONDecoder().decode([ApplicationOption].self, from: data) else {
            return []
        }
        return applications
    }

    private static func settings(
        group: String,
        defaults: [(id: String, isEnabled: Bool)]
    ) -> [String: FinderMenuItemSetting] {
        Dictionary(uniqueKeysWithValues: defaults.map { id, defaultEnabled in
            let enabledKey = enabledKey(group: group, id: id)
            let placementKey = placementKey(group: group, id: id)
            let isEnabled = store.object(forKey: enabledKey) == nil
                ? defaultEnabled
                : store.bool(forKey: enabledKey)
            let placement = store.string(forKey: placementKey)
                .flatMap(FinderMenuPlacement.init(rawValue:)) ?? .submenu

            return (id, FinderMenuItemSetting(isEnabled: isEnabled, placement: placement))
        })
    }
}
