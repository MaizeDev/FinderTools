import AppKit
import Observation

/// App 级的应用目录（B-05 / C-07）。
///
/// 启动时先读上次缓存的目录并立即广播给扩展，再用后台任务扫描新目录，
/// 扫描完成后回到主线程更新并再次广播。`AppDelegate` 不再在启动时同步扫描。
@MainActor
@Observable
final class ApplicationCatalog {
    static let shared = ApplicationCatalog()

    /// 回到前台时的自动刷新窗口：距上次刷新超过 5 分钟才刷新（C-07）。
    static let refreshInterval: TimeInterval = 300

    private(set) var applications: [ApplicationMenuOption]
    private(set) var isRefreshing = false
    private(set) var lastRefreshDate: Date?

    private var pendingRefresh = false
    private var activationObserver: NSObjectProtocol?

    /// D-04：解码后的菜单图标缓存。`OpenWithView` 每次渲染每一行都会取图标，
    /// 缓存后不再重复 `NSImage(data:)` 解码 PNG；目录刷新时整体清空。
    /// 不参与 Observation，避免在 view body 里惰性写入缓存时触发额外的刷新。
    @ObservationIgnored private var iconCache: [String: NSImage] = [:]

    private init() {
        applications = FinderMenuPreferences.installedApplications
        lastRefreshDate = FinderMenuPreferences.applicationCatalogRefreshDate
    }

    /// 启动入口：缓存目录立刻可用并广播给扩展，随后在后台刷新。
    func start() {
        FinderMenuPreferences.startSyncingWithExtension()
        observeApplicationActivation()
        refresh()
    }

    /// 手动刷新 / 自动刷新共用的入口；并发多次调用会合并成一次。
    func refresh() {
        guard !isRefreshing else {
            pendingRefresh = true
            return
        }
        isRefreshing = true

        Task {
            let refreshedApplications = await Task.detached(priority: .userInitiated) {
                AppDiscovery.allApplications()
            }.value

            applications = refreshedApplications
            lastRefreshDate = Date()
            iconCache.removeAll()
            isRefreshing = false
            FinderMenuPreferences.updateApplications(refreshedApplications)

            if pendingRefresh {
                pendingRefresh = false
                refresh()
            }
        }
    }

    /// D-04：取缓存中的图标；首次访问时解码并缓存。必须在主线程调用。
    func icon(for application: ApplicationMenuOption) -> NSImage {
        if let cachedIcon = iconCache[application.preferenceID] {
            return cachedIcon
        }

        let icon = application.icon
        iconCache[application.preferenceID] = icon
        return icon
    }

    private var needsRefresh: Bool {
        guard let lastRefreshDate else { return true }
        return Date().timeIntervalSince(lastRefreshDate) >= Self.refreshInterval
    }

    private func observeApplicationActivation() {
        guard activationObserver == nil else { return }

        // 单例与 App 同生命周期，观察者不需要注销。通知在主队列投递，
        // 用 assumeIsolated 明确回到主 Actor，避免在并发闭包里捕获可变 self。
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applicationDidBecomeActive()
            }
        }
    }

    private func applicationDidBecomeActive() {
        guard needsRefresh else { return }
        refresh()
    }
}
