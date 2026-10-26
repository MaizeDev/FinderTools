import Foundation
import ServiceManagement

/// `SMAppService.mainApp` 的薄封装（第 20 步）：只维护登录项状态与可读错误，不参与界面布局。
///
/// 用系统的 SMAppService 登录项，不自己写 LaunchAgent plist。
/// 注意：SDK 头文件明确 “Apps that use SMAppService APIs must be code signed”；
/// 本 App 目前是 ad-hoc 签名，注册可能被系统以 `kSMErrorInvalidSignature` 拒绝，
/// 所以这里把失败原因翻译成用户能看懂、能自行处理的提示。
@MainActor
enum LoginItemService {
    /// 注册/取消注册成功后发出，供设置页与主窗口顶部的提示条同步状态。
    static let statusDidChangeNotification = Notification.Name(
        "com.wheat.FinderTools.loginItemStatusDidChange"
    )

    struct ActionError: Error {
        let userMessage: String
    }

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    /// 已注册（`.requiresApproval` 也算已注册，但可能还需要用户在系统设置里允许）。
    static var isEnabled: Bool {
        switch status {
        case .enabled, .requiresApproval:
            true
        default:
            false
        }
    }

    static var requiresApproval: Bool {
        status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard status != .enabled else { return }
            do {
                try SMAppService.mainApp.register()
            } catch {
                throw makeActionError(error, action: "注册")
            }
        } else {
            guard status != .notRegistered else { return }
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                throw makeActionError(error, action: "取消注册")
            }
        }

        NotificationCenter.default.post(name: statusDidChangeNotification, object: nil)
    }

    static func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private static func makeActionError(_ error: Error, action: String) -> ActionError {
        let nsError = error as NSError
        // kSMErrorInvalidSignature = 3（见 SDK 的 SMErrors.h），常见于代码签名不被系统接受。
        if nsError.domain == SMAppServiceErrorDomain, nsError.code == 3 {
            return ActionError(
                userMessage: "登录项\(action)失败：系统认为本 App 的代码签名无效。FinderTools 没有使用开发者证书签名，可能无法注册登录项。可以把 App 放到“应用程序”文件夹后再试，或在“系统设置 → 通用 → 登录项”里手动添加；也可以每次手动打开 FinderTools。"
            )
        }
        return ActionError(
            userMessage: "登录项\(action)失败：\(nsError.localizedDescription)。可以在“系统设置 → 通用 → 登录项”里手动添加。"
        )
    }
}
