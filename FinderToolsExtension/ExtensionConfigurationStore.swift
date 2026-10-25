import Foundation
import os

/// C-06：扩展侧的配置存储。
///
/// 主 App 现在把配置拆成两条通知：设置段（`MenuConfiguration`，不含图标）与
/// 应用目录段（`[ApplicationMenuOption]`，含 36px PNG 图标）。扩展把两段分开
/// 持久化，启动时直接读取并合并；旧版单键 `menuConfiguration` 只用于升级迁移
/// 与回滚兼容。
final class ExtensionConfigurationStore {
    private enum Key {
        static let settings = "menuSettings"
        static let applicationOptions = "menuApplicationOptions"
        static let legacyConfiguration = "menuConfiguration"
    }

    private static let logger = Logger(
        subsystem: "com.wheat.FinderTools",
        category: "FinderSync"
    )

    private let preferences: UserDefaults

    private(set) var settings: MenuConfiguration
    private(set) var applicationOptions: [ApplicationMenuOption]?

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences

        let storedSettings = Self.decodeSettings(from: preferences)
        let storedOptions = Self.decodeApplicationOptions(from: preferences)

        if storedSettings == nil || storedOptions == nil,
           let legacyData = preferences.data(forKey: Key.legacyConfiguration),
           let legacy = try? JSONDecoder().decode(MenuConfiguration.self, from: legacyData) {
            // 升级迁移：把旧版整份配置拆成两个键保存。旧键保留不删，
            // 回滚到旧版本后旧扩展还能读到配置。
            Self.logger.notice("Migrated the pre-split menu configuration")
            settings = storedSettings ?? legacy.removingApplicationOptions()
            applicationOptions = storedOptions ?? legacy.applicationOptions
            persistSettings(settings)
            if let applicationOptions {
                persistApplicationOptions(applicationOptions)
            }
        } else {
            settings = storedSettings ?? .defaults
            applicationOptions = storedOptions
        }

        Self.logger.notice(
            "Loaded menu configuration: \(self.applicationOptions?.count ?? -1, privacy: .public) app options"
        )
    }

    /// 合并成 `MenuBuilder` 认识的整份配置。
    var mergedConfiguration: MenuConfiguration {
        settings.merging(applicationOptions: applicationOptions)
    }

    /// 设置段更新（开关变更 / syncRequest）。
    func updateSettings(from configuration: MenuConfiguration) {
        settings = configuration.removingApplicationOptions()
        persistSettings(settings)
    }

    /// 应用目录段更新：直接落盘主 App 发来的原始 JSON，不再重复编码。
    func updateApplicationOptions(_ options: [ApplicationMenuOption], encodedData: Data) {
        applicationOptions = options
        preferences.set(encodedData, forKey: Key.applicationOptions)
    }

    /// 旧协议（整份配置）：拆开保存；旧键也更新，回滚到旧版本后旧扩展还能读到最新配置。
    func adoptLegacyConfiguration(_ configuration: MenuConfiguration, encodedData: Data) {
        updateSettings(from: configuration)
        if let options = configuration.applicationOptions {
            applicationOptions = options
            persistApplicationOptions(options)
        }
        preferences.set(encodedData, forKey: Key.legacyConfiguration)
    }

    private func persistSettings(_ settings: MenuConfiguration) {
        guard let data = try? JSONEncoder().encode(settings) else {
            Self.logger.error("Failed to encode menu settings for storage")
            return
        }
        preferences.set(data, forKey: Key.settings)
    }

    private func persistApplicationOptions(_ options: [ApplicationMenuOption]) {
        guard let data = try? JSONEncoder().encode(options) else {
            Self.logger.error("Failed to encode the application catalog for storage")
            return
        }
        preferences.set(data, forKey: Key.applicationOptions)
    }

    private static func decodeSettings(from preferences: UserDefaults) -> MenuConfiguration? {
        guard let data = preferences.data(forKey: Key.settings) else { return nil }
        guard let decoded = try? JSONDecoder().decode(MenuConfiguration.self, from: data) else {
            logger.error("Ignored an invalid stored menu settings value")
            return nil
        }
        return decoded.removingApplicationOptions()
    }

    private static func decodeApplicationOptions(
        from preferences: UserDefaults
    ) -> [ApplicationMenuOption]? {
        guard let data = preferences.data(forKey: Key.applicationOptions) else { return nil }
        guard let decoded = try? JSONDecoder().decode([ApplicationMenuOption].self, from: data) else {
            logger.error("Ignored an invalid stored application catalog value")
            return nil
        }
        return decoded
    }
}
