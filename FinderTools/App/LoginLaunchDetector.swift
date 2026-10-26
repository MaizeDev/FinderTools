import AppKit

/// 判断本次启动是否由“登录时自动启动”触发（第 20 步）。
///
/// 依据：macOS SDK 的 `AERegistry.h` 为 `kAEOpenApplication` 事件定义了
/// `keyAELaunchedAsLogInItem`（`'lgit'`）参数，登录项启动时由系统附带；
/// 普通启动的同一事件不带这个参数。实现只读取 `currentAppleEvent`，不接管事件处理，
/// 因此不会改变正常启动、打开文件等行为。
///
/// 已用 /tmp 的 SwiftUI 探针确认：正常启动时 `applicationDidFinishLaunching` 里能拿到
/// `oapp` 事件且没有 `lgit` 参数。真正的登录项启动只能重启电脑验证。
nonisolated enum LoginLaunchDetector {
    /// 纯判断逻辑，便于单元测试。
    static func isLoginItemLaunch(currentAppleEvent event: NSAppleEventDescriptor?) -> Bool {
        guard let event,
              event.eventID == AEEventID(kAEOpenApplication) else {
            return false
        }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil
    }

    @MainActor
    static func isLoginItemLaunch() -> Bool {
        isLoginItemLaunch(currentAppleEvent: NSAppleEventManager.shared().currentAppleEvent)
    }
}
