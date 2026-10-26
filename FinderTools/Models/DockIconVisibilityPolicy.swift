/// 纯逻辑：根据「关闭后隐藏 Dock 图标」开关与剩余可见主窗口数量，
/// 决定 App 应处于 regular 还是 accessory 激活策略。
///
/// 不依赖 AppKit，便于单元测试；真正的 `NSApplication.setActivationPolicy`
/// 由 `DockIconVisibilityController` 负责。
nonisolated enum DockIconVisibilityPolicy {
    enum ActivationPolicy: Equatable, Sendable {
        case regular
        case accessory
    }

    /// 一扇窗口参与“主窗口”判定所需的快照，避免纯逻辑直接依赖 AppKit。
    struct MainWindowSnapshot: Equatable, Sendable {
        /// NSOpenPanel、NSSavePanel、NSAlert 等都是 NSPanel。
        let isPanel: Bool
        let isUtilityWindow: Bool
        let canBecomeMain: Bool
        let isVisible: Bool
        /// 正在关闭的窗口在 `willClose` 时仍然可见，但不应计入剩余数量。
        let isClosing: Bool
    }

    static func activationPolicy(
        hideDockIconAfterLastWindowClosed: Bool,
        visibleMainWindowCount: Int
    ) -> ActivationPolicy {
        guard hideDockIconAfterLastWindowClosed, visibleMainWindowCount == 0 else {
            return .regular
        }
        return .accessory
    }

    /// 剩余可见主窗口数量。面板（NSOpenPanel / NSAlert 等）、工具窗口、
    /// 不能成为主窗口的窗口、不可见窗口和正在关闭的窗口都不计入。
    static func visibleMainWindowCount(in windows: [MainWindowSnapshot]) -> Int {
        windows.filter { window in
            !window.isClosing
                && !window.isPanel
                && !window.isUtilityWindow
                && window.canBecomeMain
                && window.isVisible
        }.count
    }
}
