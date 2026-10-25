import Foundation

/// `findertools://` 解析后的命令。
///
/// 纯类型：不访问 AppKit、不持有状态，便于 `ActionValidator` 做校验和单元测试。
/// 解析只负责“参数是否齐全”，安全规则全部在 `ActionValidator` 里。
nonisolated struct FinderCommand: Equatable {
    enum Action: Equatable {
        case create(directory: URL, fileExtension: String)
        case terminal(directory: URL)
        case open(application: URL, items: [URL])
        case choose(items: [URL])
    }

    let action: Action

    init(url: URL) throws {
        guard url.scheme == "findertools",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let actionName = components.host else {
            throw ActionValidationError.invalidCommand
        }

        var values: [String: [String]] = [:]
        for queryItem in components.queryItems ?? [] {
            guard let value = queryItem.value else { continue }
            values[queryItem.name, default: []].append(value)
        }

        let itemURLs = (values["item"] ?? []).map { URL(fileURLWithPath: $0) }

        switch actionName {
        case "create":
            guard let directoryPath = values["directory"]?.first, !directoryPath.isEmpty,
                  let fileExtension = values["type"]?.first, !fileExtension.isEmpty else {
                throw ActionValidationError.invalidCommand
            }
            action = .create(
                directory: URL(fileURLWithPath: directoryPath, isDirectory: true),
                fileExtension: fileExtension.lowercased()
            )

        case "terminal":
            guard let directoryPath = values["directory"]?.first, !directoryPath.isEmpty else {
                throw ActionValidationError.invalidCommand
            }
            action = .terminal(directory: URL(fileURLWithPath: directoryPath, isDirectory: true))

        case "open":
            guard let applicationPath = values["application"]?.first, !applicationPath.isEmpty,
                  !itemURLs.isEmpty else {
                throw ActionValidationError.invalidCommand
            }
            action = .open(application: URL(fileURLWithPath: applicationPath), items: itemURLs)

        case "choose":
            guard !itemURLs.isEmpty else { throw ActionValidationError.invalidCommand }
            action = .choose(items: itemURLs)

        default:
            throw ActionValidationError.invalidCommand
        }
    }

    /// 供单元测试直接构造命令，跳过 URL 解析。
    init(action: Action) {
        self.action = action
    }

    /// 需要访问的目标路径（用于“必须在授权文件夹内”的校验）。
    var targetURLs: [URL] {
        switch action {
        case .create(let directory, _): [directory]
        case .terminal(let directory): [directory]
        case .open(_, let items): items
        case .choose(let items): items
        }
    }
}
