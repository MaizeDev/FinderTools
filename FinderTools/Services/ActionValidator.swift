import Foundation

/// 校验失败的原因。`LocalizedError` 文案只描述用户可见的信息，不泄露内部细节。
nonisolated enum ActionValidationError: Error, Equatable, LocalizedError {
    case invalidCommand
    case unsupportedFileType
    case tooManyItems(limit: Int)
    case targetOutsideAuthorizedFolders
    case applicationNotAllowed

    var errorDescription: String? {
        switch self {
        case .invalidCommand:
            "操作参数不完整或不正确。"
        case .unsupportedFileType:
            "不支持这种文件类型。"
        case .tooManyItems(let limit):
            "一次最多只能操作 \(limit) 个项目。"
        case .targetOutsideAuthorizedFolders:
            "目标不在已授权的文件夹内。"
        case .applicationNotAllowed:
            "这个应用不在已启用的打开方式列表中。"
        }
    }
}

/// `findertools://` 的纯校验器：输入解析后的命令，输出校验结果或错误。
///
/// 分两段调用：
/// - `validateParameters(_:)`：与授权无关的规则（类型白名单、数量上限、App 白名单），
///   在弹授权提示之前调用，恶意 URL 不会触发授权流程。
/// - `validateAuthorizedTargets(_:)`：所有目标必须落在可用授权文件夹内，取得访问权限后再校验。
nonisolated struct ActionValidator {
    static let maximumItemCount = 500
    static let supportedCreateExtensions: Set<String> =
        Set(NewFileType.allCases.map(\.fileExtension))

    private let enabledApplicationPaths: Set<String>
    private let authorizedFolderURLs: [URL]

    init(enabledApplicationPaths: Set<String>, authorizedFolderPaths: [String]) {
        // D-09：统一走 PathContainment（展开符号链接 + 按卷的大小写规则比较），
        // 不再在两处各写一遍大小写敏感的前缀判断。
        self.enabledApplicationPaths = Set(enabledApplicationPaths.map {
            PathContainment.canonicalPath(URL(fileURLWithPath: $0))
        })
        self.authorizedFolderURLs = authorizedFolderPaths.map {
            PathContainment.canonicalURL(URL(fileURLWithPath: $0))
        }
    }

    func validateParameters(_ command: FinderCommand) throws {
        switch command.action {
        case .create(_, let fileExtension):
            guard Self.supportedCreateExtensions.contains(fileExtension) else {
                throw ActionValidationError.unsupportedFileType
            }

        case .terminal:
            break

        case .open(let application, let items):
            try Self.validateItemCount(items)
            guard application.pathExtension.lowercased() == "app",
                  FileManager.default.fileExists(atPath: application.path),
                  enabledApplicationPaths.contains(PathContainment.canonicalPath(application)) else {
                throw ActionValidationError.applicationNotAllowed
            }

        case .choose(let items):
            try Self.validateItemCount(items)
        }
    }

    func validateAuthorizedTargets(_ command: FinderCommand) throws {
        for targetURL in command.targetURLs {
            let isInsideAuthorizedFolder = authorizedFolderURLs.contains { folderURL in
                PathContainment.isInside(targetURL, folder: folderURL)
            }
            guard isInsideAuthorizedFolder else {
                throw ActionValidationError.targetOutsideAuthorizedFolders
            }
        }
    }

    private static func validateItemCount(_ items: [URL]) throws {
        guard items.count <= maximumItemCount else {
            throw ActionValidationError.tooManyItems(limit: maximumItemCount)
        }
    }
}

/// create 动作的简单频率限制：同一个目录在 1 秒内最多允许 5 次。
///
/// 状态只保存在主 App 内存里，不写存储；`now` 可注入，方便单元测试。
nonisolated struct CreateRateLimiter {
    static let maximumCreates = 5
    static let window: TimeInterval = 1

    private var recentCreateDates: [String: [Date]] = [:]

    mutating func allowCreate(in directory: URL, now: Date = Date()) -> Bool {
        let key = directory.standardizedFileURL.path
        let cutoff = now.addingTimeInterval(-Self.window)
        var timestamps = (recentCreateDates[key] ?? []).filter { $0 > cutoff }

        guard timestamps.count < Self.maximumCreates else {
            recentCreateDates[key] = timestamps
            return false
        }

        timestamps.append(now)
        recentCreateDates[key] = timestamps
        return true
    }
}
