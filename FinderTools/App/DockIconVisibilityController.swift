import AppKit

/// 只负责“关闭主窗口后切换激活策略”的 AppKit 薄层；
/// 该用 regular 还是 accessory 由 `DockIconVisibilityPolicy` 的纯逻辑决定。
@MainActor
final class DockIconVisibilityController {
    private let preferences = AppPreferences()
    private var isStarted = false

    /// 在 App 启动时调用一次；观察者跟随 App 生命周期，不需要移除。
    func start() {
        guard !isStarted else { return }
        isStarted = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    /// `willClose` 回调里不要同步切换激活策略，也不要在这里数窗口：
    /// 此时正在关闭的窗口仍然可见、仍在 `NSApp.windows` 里。
    /// 只记录它，把统计和切换延后到下一个主线程循环。
    @objc private func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              Self.canBeMainWindow(closingWindow) else { return }

        let closingWindowIdentifier = ObjectIdentifier(closingWindow)
        Task { @MainActor [weak self] in
            self?.updateActivationPolicy(closingWindowIdentifier: closingWindowIdentifier)
        }
    }

    private func updateActivationPolicy(closingWindowIdentifier: ObjectIdentifier) {
        let snapshots = NSApp.windows.map { window in
            DockIconVisibilityPolicy.MainWindowSnapshot(
                isPanel: window is NSPanel,
                isUtilityWindow: window.styleMask.contains(.utilityWindow),
                canBecomeMain: window.canBecomeMain,
                isVisible: window.isVisible,
                isClosing: ObjectIdentifier(window) == closingWindowIdentifier
            )
        }
        let remainingVisibleMainWindowCount =
            DockIconVisibilityPolicy.visibleMainWindowCount(in: snapshots)
        let policy = DockIconVisibilityPolicy.activationPolicy(
            hideDockIconAfterLastWindowClosed: preferences.hideDockIconAfterLastWindowClosed,
            visibleMainWindowCount: remainingVisibleMainWindowCount
        )
        apply(policy)
    }

    private func apply(_ policy: DockIconVisibilityPolicy.ActivationPolicy) {
        let activationPolicy: NSApplication.ActivationPolicy =
            policy == .accessory ? .accessory : .regular
        guard NSApp.activationPolicy() != activationPolicy else { return }
        NSApp.setActivationPolicy(activationPolicy)
    }

    /// 主窗口候选：非 NSPanel、非工具窗口、且能成为主窗口。
    /// 授权弹窗（NSAlert）与文件夹选择面板（NSOpenPanel）都是 NSPanel，因此关闭它们不会触发切换。
    private static func canBeMainWindow(_ window: NSWindow) -> Bool {
        guard !(window is NSPanel) else { return false }
        guard !window.styleMask.contains(.utilityWindow) else { return false }
        return window.canBecomeMain
    }
}
