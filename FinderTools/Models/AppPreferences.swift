import Foundation

/// “通用”页的偏好。
///
/// 主 App target 默认 `MainActor` 隔离，这里显式标 `nonisolated`，
/// 让读取偏好的代码（包括单元测试）不依赖调用方的隔离域。
nonisolated struct AppPreferences {
    /// 「关闭窗口后隐藏 Dock 图标」的 UserDefaults 键。
    static let hideDockIconAfterLastWindowClosedKey =
        "general.hideDockIconAfterLastWindowClosed"

    /// 「不再提示登录启动提示条」的 UserDefaults 键。
    static let hasDismissedLaunchAtLoginHintKey =
        "general.hasDismissedLaunchAtLoginHint"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 默认 `false`：关闭最后一个主窗口后沿用 V1.1.1 的行为，Dock 图标保留。
    var hideDockIconAfterLastWindowClosed: Bool {
        get { defaults.bool(forKey: Self.hideDockIconAfterLastWindowClosedKey) }
        nonmutating set {
            defaults.set(newValue, forKey: Self.hideDockIconAfterLastWindowClosedKey)
        }
    }

    /// 默认 `false`：只要登录项没开启，就在主窗口顶部显示提示条。
    var hasDismissedLaunchAtLoginHint: Bool {
        get { defaults.bool(forKey: Self.hasDismissedLaunchAtLoginHintKey) }
        nonmutating set {
            defaults.set(newValue, forKey: Self.hasDismissedLaunchAtLoginHintKey)
        }
    }
}
