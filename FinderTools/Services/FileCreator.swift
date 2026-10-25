import AppKit
import os

/// `create` 动作：在目标文件夹里创建唯一命名的文件，并让 Finder 选中它。
///
/// Office 三种类型复制主 App Resources 里的空白模板，其余写初始文本。
@MainActor
enum FileCreator {
    private static let logger = Logger(subsystem: "com.wheat.FinderTools", category: "FinderActionHandler")

    static func create(in directoryURL: URL, fileExtension: String) throws {
        guard let fileType = NewFileType(fileExtension: fileExtension) else {
            throw FinderActionError.unsupportedFileType
        }

        let destinationURL = uniqueDestinationURL(in: directoryURL, fileExtension: fileType.fileExtension)

        if fileType.usesBlankTemplate {
            // 空白模板随主 App 打包（FinderTools/Resources/blank.*），不再去扩展 bundle 里取。
            guard let templateURL = Bundle.main.url(
                forResource: "blank",
                withExtension: fileType.fileExtension
            ) else {
                throw FinderActionError.missingTemplate(fileType.fileExtension)
            }
            try FileManager.default.copyItem(at: templateURL, to: destinationURL)
        } else {
            try Data(fileType.initialText.utf8).write(to: destinationURL, options: .withoutOverwriting)
        }

        logger.notice("Created file: \(destinationURL.path, privacy: .public)")
        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
    }

    private static func uniqueDestinationURL(in directoryURL: URL, fileExtension: String) -> URL {
        var index = 1

        while true {
            let suffix = index == 1 ? "" : " \(index)"
            let candidate = directoryURL.appendingPathComponent("未命名\(suffix).\(fileExtension)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}

private enum FinderActionError: LocalizedError {
    case unsupportedFileType
    case missingTemplate(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            "不支持这种文件类型。"
        case .missingTemplate(let fileExtension):
            "找不到 .\(fileExtension) 空白模板。"
        }
    }
}
