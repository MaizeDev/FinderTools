import AppKit
import os

/// 扩展侧判断主 App 是否在运行（第 20 步）。
///
/// 选型：每次 `menu(for:)` 实时查询，而不是依赖“主 App 退出”通知。
/// 实时查询能同时覆盖正常退出、活动监视器强制退出与崩溃——后两者不会发退出通知；
/// 而且不需要扩展维护额外状态、也不需要主 App 退出时清空 `directoryURLs`（清空后还要
/// 靠重新广播恢复，扩展未加载或漏收通知时会残留）。
///
/// 依据：`NSRunningApplication` 是 LaunchServices 的公开查询 API，App Sandbox 不限制它。
/// 本仓库扩展在 V1.1.1 里已经用同一个 API 判断主 App 是否在运行（原 `CommandSender`）；
/// 另用启用 App Sandbox 的探针实测：能查到 Finder 与系统运行 App 列表，耗时约
/// 0.001～0.014ms。真正的 FinderSync.appex 内表现仍需在实机右键验收。
nonisolated enum MainAppLiveness {
    private static let logger = Logger(
        subsystem: "com.wheat.FinderTools",
        category: "FinderSync"
    )

    static func isMainAppRunning() -> Bool {
        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: FinderToolsBundleIdentifier.mainApp
        )
        return applications.contains { !$0.isTerminated }
    }

    /// `menu(for:)` 专用：记录 running 结果与检查耗时（debug 级别，避免 notice 刷屏）。
    static func isMainAppRunningForMenu() -> Bool {
        let startTime = ProcessInfo.processInfo.systemUptime
        let isRunning = isMainAppRunning()
        let elapsedMilliseconds = (ProcessInfo.processInfo.systemUptime - startTime) * 1_000
        logger.debug(
            "Main App liveness: running=\(isRunning, privacy: .public), check=\(elapsedMilliseconds, format: .fixed(precision: 3)) ms"
        )
        if !isRunning {
            logger.debug("Suppressed the Finder menu because FinderTools is not running")
        }
        return isRunning
    }
}
