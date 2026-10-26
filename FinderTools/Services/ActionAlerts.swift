import AppKit

/// 用户可见的弹窗：错误提示、授权提示。
@MainActor
enum ActionAlerts {
    /// 授权/提示窗的前台展示。
    ///
    /// 第 18 步之后 App 可能在 `.accessory`（Dock 图标隐藏、没有主窗口）状态下被
    /// `findertools://` 拉起。V1.1.1 在这个状态下用 `NSApp.activate()` 已验证可以弹窗，
    /// 所以默认沿用现有行为；若真机验收发现拿不到键盘焦点，把
    /// `temporarilyPromotesToRegular` 改成 `true`：弹窗前临时切 `.regular` + activate，
    /// 弹窗结束后恢复进入前的激活策略。
    ///
    /// 授权面板（`NSOpenPanel`）与 `NSAlert` 都是 `NSPanel`，`DockIconVisibilityController`
    /// 不把它们计入主窗口，因此它们的打开/关闭不会触发隐藏 Dock 图标的逻辑。
    private enum ForegroundPresentation {
        /// 由常量控制，默认关闭（不在弹窗前临时切换激活策略）。
        static let temporarilyPromotesToRegular = false

        static func perform<Result>(_ body: () -> Result) -> Result {
            let policyBeforePresentation = NSApp.activationPolicy()
            let promotesToRegular = temporarilyPromotesToRegular
                && policyBeforePresentation == .accessory

            if promotesToRegular {
                NSApp.setActivationPolicy(.regular)
                NSApp.unhide(nil)
            }
            NSApp.activate()

            defer {
                if promotesToRegular {
                    // 恢复进入前的策略，而不是重新推导，避免误触发 Dock 图标的显示/隐藏。
                    NSApp.setActivationPolicy(policyBeforePresentation)
                }
            }
            return body()
        }
    }

    static func showError(_ title: String, message: String) {
        ForegroundPresentation.perform {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    /// 第 19 步：目标位于 `/System` 等不允许操作的位置时，只给一次简短提示，不请求授权。
    static func showUnsupportedLocation(for targetURLs: [URL]) {
        ForegroundPresentation.perform {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "此位置不支持"
            alert.informativeText = """
                FinderTools 不能在系统位置或无法授权的位置执行操作：

                \(targetsDescription(for: targetURLs))

                请在其他文件夹中使用 FinderTools。
                """
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    /// 用户选中的文件夹本身属于不可授权的位置（`/`、`/Volumes`、`/Users`、`/Applications` 根）。
    static func showUnsupportedAuthorizationFolder(_ folderURL: URL) {
        ForegroundPresentation.perform {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "这个文件夹不能授权"
            alert.informativeText = """
                FinderTools 不能把以下位置选作授权文件夹：

                \(folderURL.path(percentEncoded: false))

                请选择更具体的位置，例如桌面、下载、文稿，或外置硬盘上的某个文件夹。
                """
            alert.addButton(withTitle: "好")
            alert.runModal()
        }
    }

    /// 请求用户授权一个包含所有目标的文件夹（B-04 的“最多重试一次”由调用方控制）。
    ///
    /// 第 19 步：授权窗口本身就是一个 `NSOpenPanel`——说明“需要文件夹权限”、
    /// 列出目标路径、默认定位到目标所在文件夹、按钮文案为“授权”，用户点一下即可。
    ///
    /// - Returns: 新授权是否已覆盖全部目标。为 `true` 时调用方应自动重试一次。
    static func requestFolderAuthorization(for targetURLs: [URL], suggestedDirectory: URL) -> Bool {
        ForegroundPresentation.perform {
            guard let chosenFolder = FolderAccessManager.shared.chooseFolder(
                suggestedDirectory: suggestedDirectory,
                title: "需要文件夹权限",
                message: authorizationMessage(for: targetURLs),
                prompt: "授权"
            ) else {
                // 用户取消（或选了不可授权的位置，那里已经给过提示）：静默结束，不弹错误。
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
            return RealHome.url
        }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: firstTarget.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return firstTarget
        }
        return firstTarget.deletingLastPathComponent()
    }

    /// 授权面板的说明文字。目标是个人目录本身时额外提醒：这会授权整个个人目录。
    private static func authorizationMessage(for targetURLs: [URL]) -> String {
        var message = """
            需要访问：
            \(targetsDescription(for: targetURLs))

            请选择一个包含以上项目的文件夹，然后点击“授权”。FinderTools 只会在已授权的文件夹及其子文件夹里执行操作。
            """
        if targetURLs.contains(where: { AuthorizationLocationPolicy.isPersonalHomeDirectory($0) }) {
            message += """


                注意：目标包含你的个人目录本身，授权后 FinderTools 将可以访问整个个人目录。建议改选更具体的位置（例如桌面、下载、文稿）。
                """
        }
        return message
    }
}
