import AppKit

/// 用户可见的弹窗：错误提示、文件夹授权提示。
@MainActor
enum ActionAlerts {
    static func showError(_ title: String, message: String) {
        NSApp.activate()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    /// 请求用户授权一个包含所有目标的文件夹（B-04 的“最多重试一次”由调用方控制）。
    ///
    /// - Returns: 新授权是否已覆盖全部目标。为 `true` 时调用方应自动重试一次。
    static func requestFolderAuthorization(for targetURLs: [URL], suggestedDirectory: URL) -> Bool {
        NSApp.activate()

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "需要文件夹权限"
        alert.informativeText = "需要访问：\n\(targetsDescription(for: targetURLs))\n\n请选择一个包含该项目的文件夹。你可以只授权桌面、下载等需要使用的位置，并在“扩展权限”页面中随时添加或移除。"
        alert.addButton(withTitle: "选择文件夹")
        alert.addButton(withTitle: "取消")

        guard alert.runModal() == .alertFirstButtonReturn,
              let chosenFolder = FolderAccessManager.shared.chooseFolder(suggestedDirectory: suggestedDirectory) else {
            return false
        }

        // 授权后先确认目标是否真的被覆盖，避免“选了无关文件夹 → 再弹一次提示”的循环。
        let uncoveredTargets = targetURLs.filter { !FolderAccessManager.shared.isAuthorized($0) }
        guard uncoveredTargets.isEmpty else {
            showError(
                "所选文件夹不包含要操作的项目",
                message: "你选择的是：\n\(chosenFolder.path(percentEncoded: false))\n\n要操作的项目位于：\n\(targetsDescription(for: uncoveredTargets))\n\n请重新选择包含该项目的文件夹。"
            )
            return false
        }

        return true
    }

    /// 目标路径列表（最多显示 5 条，避免弹窗过长）。
    static func targetsDescription(for targetURLs: [URL]) -> String {
        let maximumCount = 5
        var lines = targetURLs.prefix(maximumCount)
            .map { $0.path(percentEncoded: false) }
            .joined(separator: "\n")
        if targetURLs.count > maximumCount {
            lines += "\n…等 \(targetURLs.count) 项"
        }
        return lines
    }

    /// 授权面板默认打开的位置：目标是文件夹就用它本身，否则用父目录。
    static func suggestedAuthorizationDirectory(for targetURLs: [URL]) -> URL {
        guard let firstTarget = targetURLs.first else {
            return FileManager.default.homeDirectoryForCurrentUser
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: firstTarget.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return firstTarget
        }
        return firstTarget.deletingLastPathComponent()
    }
}
