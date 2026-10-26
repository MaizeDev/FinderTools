import Foundation
import os

/// 处理 `findertools://` 命令：解析 → 校验 → 按动作分发给创建、打开、弹窗模块。
@MainActor
final class FinderActionHandler {
    static let shared = FinderActionHandler()

    private let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderActionHandler")

    private init() {}

    /// create 动作的频率限制（同一目录 1 秒内最多 5 次），只保存在内存里。
    private var createRateLimiter = CreateRateLimiter()

    func handle(_ commandURL: URL) {
        handle(commandURL, isRetry: false)
    }

    /// - Parameter isRetry: 已经自动重试过一次。为 `true` 时不再弹授权提示，直接报错结束，
    ///   保证每条命令最多自动重试一次（B-04）。
    private func handle(_ commandURL: URL, isRetry: Bool) {
        let command: FinderCommand
        do {
            command = try FinderCommand(url: commandURL)
        } catch {
            logger.error("Ignored an invalid Finder action URL: \(commandURL.absoluteString, privacy: .public)")
            if commandURL.scheme == "findertools" {
                ActionAlerts.showError("操作失败", message: error.localizedDescription)
            }
            return
        }

        do {
            // 与授权无关的参数校验先做，恶意 URL 不会触发授权提示（B-03）。
            let validator = currentValidator()
            try validator.validateParameters(command)

            // 第 19 步：系统敏感位置不请求授权，只给一次简短提示并结束。
            guard AuthorizationLocationPolicy.areTargetsSupported(command.targetURLs) else {
                logger.notice(
                    "Ignored a Finder action in an unsupported location: \(commandURL.absoluteString, privacy: .public)"
                )
                ActionAlerts.showUnsupportedLocation(for: command.targetURLs)
                return
            }

            switch command.action {
            case .create(let directoryURL, let fileExtension):
                guard let accessToken = requestAccessIfNeeded(
                    to: [directoryURL],
                    suggestedDirectory: directoryURL,
                    commandURL: commandURL,
                    isRetry: isRetry
                ) else { return }
                try validator.validateAuthorizedTargets(command)
                guard createRateLimiter.allowCreate(in: directoryURL) else {
                    logger.notice("Ignored a create request due to rate limiting: \(directoryURL.path, privacy: .public)")
                    _ = accessToken
                    return
                }
                try FileCreator.create(in: directoryURL, fileExtension: fileExtension)
                _ = accessToken

            case .terminal(let directoryURL):
                guard let accessToken = requestAccessIfNeeded(
                    to: [directoryURL],
                    suggestedDirectory: directoryURL,
                    commandURL: commandURL,
                    isRetry: isRetry
                ) else { return }
                try validator.validateAuthorizedTargets(command)
                WorkspaceOpener.openInTerminal(directoryURL, accessToken: accessToken)

            case .open(let applicationURL, let itemURLs):
                guard let accessToken = requestAccessIfNeeded(
                    to: itemURLs,
                    suggestedDirectory: ActionAlerts.suggestedAuthorizationDirectory(for: itemURLs),
                    commandURL: commandURL,
                    isRetry: isRetry
                ) else { return }
                try validator.validateAuthorizedTargets(command)
                WorkspaceOpener.open(itemURLs, with: applicationURL, accessToken: accessToken)

            case .choose(let itemURLs):
                guard let accessToken = requestAccessIfNeeded(
                    to: itemURLs,
                    suggestedDirectory: ActionAlerts.suggestedAuthorizationDirectory(for: itemURLs),
                    commandURL: commandURL,
                    isRetry: isRetry
                ) else { return }
                try validator.validateAuthorizedTargets(command)
                WorkspaceOpener.chooseApplication(for: itemURLs, accessToken: accessToken)
            }
        } catch {
            logger.error("Finder action failed: \(error.localizedDescription, privacy: .public)")
            ActionAlerts.showError("操作失败", message: error.localizedDescription)
        }
    }

    /// 用当前“已启用应用”和“可用授权文件夹”构造纯校验器。
    private func currentValidator() -> ActionValidator {
        ActionValidator(
            enabledApplicationPaths: Set(FinderMenuPreferences.enabledApplications.map(\.path)),
            authorizedFolderPaths: FolderAccessManager.shared.authorizedFolders
                .filter(\.isAvailable)
                .compactMap(\.url)
                .map(\.path)
        )
    }

    /// 取访问令牌；取不到时最多请求一次文件夹授权（B-04）。
    private func requestAccessIfNeeded(
        to targetURLs: [URL],
        suggestedDirectory: URL,
        commandURL: URL,
        isRetry: Bool
    ) -> FolderAccessToken? {
        if let accessToken = FolderAccessManager.shared.beginAccess(to: targetURLs) {
            return accessToken
        }

        // 每条命令最多自动重试一次：第二次仍拿不到权限就直接报错，不再弹授权提示。
        guard !isRetry else {
            ActionAlerts.showError(
                "仍然没有文件夹权限",
                message: "无法访问：\n\(ActionAlerts.targetsDescription(for: targetURLs))"
            )
            return nil
        }

        if ActionAlerts.requestFolderAuthorization(for: targetURLs, suggestedDirectory: suggestedDirectory) {
            // 新授权已覆盖全部目标：只自动重试一次。
            handle(commandURL, isRetry: true)
        }
        return nil
    }
}
