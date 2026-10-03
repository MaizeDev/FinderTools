import AppKit
import UniformTypeIdentifiers

struct ApplicationOption: Identifiable, Codable, Sendable {
    let preferenceID: String
    let name: String
    let path: String
    let fallbackSymbol: String
    let isEnabledByDefault: Bool
    let supportedExtensions: [String]
    let opensDirectories: Bool
    let menuIconData: Data?

    var id: String { preferenceID }
    var url: URL { URL(fileURLWithPath: path) }
    var isInstalled: Bool { FileManager.default.fileExists(atPath: path) }

    @MainActor
    var icon: NSImage {
        if let menuIconData, let cachedIcon = NSImage(data: menuIconData) {
            return cachedIcon
        }
        if isInstalled {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: name)
            ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: name)!
    }
}

enum AppDiscovery {
    private static let excludedBundleIdentifiers: Set<String> = [
        "com.alibaba.tongyi",
        "com.openai.chat",
        "com.openai.codex"
    ]

    private static let iconCacheLock = NSLock()
    private static var iconCache: [String: Data] = [:]

    private struct CuratedApplication {
        let preferenceID: String
        let name: String
        let path: String
        let fallbackSymbol: String
        let fallbackExtensions: [String]
        let opensDirectories: Bool

        init(
            preferenceID: String,
            name: String,
            path: String,
            fallbackSymbol: String,
            fallbackExtensions: [String] = [],
            opensDirectories: Bool = false
        ) {
            self.preferenceID = preferenceID
            self.name = name
            self.path = path
            self.fallbackSymbol = fallbackSymbol
            self.fallbackExtensions = fallbackExtensions
            self.opensDirectories = opensDirectories
        }

        func option(matchedExtensions: Set<String>) -> ApplicationOption {
            ApplicationOption(
                preferenceID: preferenceID,
                name: name,
                path: path,
                fallbackSymbol: fallbackSymbol,
                isEnabledByDefault: true,
                supportedExtensions: Array(matchedExtensions.union(fallbackExtensions)).sorted(),
                opensDirectories: opensDirectories,
                menuIconData: cachedMenuIconData(for: path)
            )
        }
    }

    private static let commonExtensions = [
        "txt", "md", "rtf", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv",
        "json", "yaml", "yml", "xml", "html", "css", "js", "ts", "swift", "py", "java", "c", "h", "cpp",
        "jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "tiff",
        "mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv", "avi",
        "zip", "7z", "rar", "tar", "gz"
    ]

    private static let textAndCodeExtensions = [
        "txt", "md", "rtf", "csv", "json", "yaml", "yml", "xml", "html", "css",
        "js", "ts", "swift", "py", "java", "c", "h", "cpp"
    ]

    private static let curatedApplications = [
        CuratedApplication(preferenceID: "textedit", name: "文本编辑", path: "/System/Applications/TextEdit.app", fallbackSymbol: "doc.text", fallbackExtensions: textAndCodeExtensions),
        CuratedApplication(preferenceID: "preview", name: "预览", path: "/System/Applications/Preview.app", fallbackSymbol: "doc.richtext", fallbackExtensions: ["pdf", "jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "tiff"]),
        CuratedApplication(preferenceID: "terminal", name: "终端", path: "/System/Applications/Utilities/Terminal.app", fallbackSymbol: "terminal", opensDirectories: true),
        CuratedApplication(preferenceID: "iterm", name: "iTerm", path: "/Applications/iTerm.app", fallbackSymbol: "terminal", opensDirectories: true),
        CuratedApplication(preferenceID: "vscode", name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: textAndCodeExtensions, opensDirectories: true),
        CuratedApplication(preferenceID: "cursor", name: "Cursor", path: "/Applications/Cursor.app", fallbackSymbol: "cursorarrow", fallbackExtensions: textAndCodeExtensions, opensDirectories: true),
        CuratedApplication(preferenceID: "sublime", name: "Sublime Text", path: "/Applications/Sublime Text.app", fallbackSymbol: "text.alignleft", fallbackExtensions: textAndCodeExtensions, opensDirectories: true),
        CuratedApplication(preferenceID: "bbedit", name: "BBEdit", path: "/Applications/BBEdit.app", fallbackSymbol: "pencil", fallbackExtensions: textAndCodeExtensions),
        CuratedApplication(preferenceID: "typora", name: "Typora", path: "/Applications/Typora.app", fallbackSymbol: "textformat", fallbackExtensions: ["txt", "md", "html"]),
        CuratedApplication(preferenceID: "iina", name: "IINA", path: "/Applications/IINA.app", fallbackSymbol: "play.rectangle", fallbackExtensions: ["mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv", "avi"]),
        CuratedApplication(preferenceID: "word", name: "Microsoft Word", path: "/Applications/Microsoft Word.app", fallbackSymbol: "doc.text", fallbackExtensions: ["doc", "docx", "rtf", "txt", "pdf"]),
        CuratedApplication(preferenceID: "excel", name: "Microsoft Excel", path: "/Applications/Microsoft Excel.app", fallbackSymbol: "tablecells", fallbackExtensions: ["xls", "xlsx", "csv"]),
        CuratedApplication(preferenceID: "powerpoint", name: "Microsoft PowerPoint", path: "/Applications/Microsoft PowerPoint.app", fallbackSymbol: "rectangle.on.rectangle.angled", fallbackExtensions: ["ppt", "pptx", "pdf"]),
        CuratedApplication(preferenceID: "xcode", name: "Xcode", path: "/Applications/Xcode.app", fallbackSymbol: "hammer", fallbackExtensions: ["swift", "c", "h", "cpp", "java"], opensDirectories: true)
    ]

    nonisolated static func allApplications() -> [ApplicationOption] {
        let curatedByPath = Dictionary(uniqueKeysWithValues: curatedApplications.map { (standardizedPath($0.path), $0) })
        var extensionsByApplicationPath: [String: Set<String>] = [:]

        for fileExtension in commonExtensions {
            guard let contentType = UTType(filenameExtension: fileExtension) else { continue }

            for applicationURL in NSWorkspace.shared.urlsForApplications(toOpen: contentType)
            where isEligibleApplication(applicationURL) {
                extensionsByApplicationPath[standardizedPath(applicationURL.path), default: []].insert(fileExtension)
            }
        }

        var applicationsByPath: [String: ApplicationOption] = [:]
        for (path, matchedExtensions) in extensionsByApplicationPath {
            if let curated = curatedByPath[path] {
                applicationsByPath[path] = curated.option(matchedExtensions: matchedExtensions)
            } else if let discovered = discoveredApplication(at: URL(fileURLWithPath: path), matchedExtensions: matchedExtensions) {
                applicationsByPath[path] = discovered
            }
        }

        for curated in curatedApplications where FileManager.default.fileExists(atPath: curated.path) {
            let path = standardizedPath(curated.path)
            if applicationsByPath[path] == nil {
                applicationsByPath[path] = curated.option(matchedExtensions: [])
            }
        }

        var applicationsByID: [String: ApplicationOption] = [:]
        for application in applicationsByPath.values {
            guard let existing = applicationsByID[application.preferenceID] else {
                applicationsByID[application.preferenceID] = application
                continue
            }

            if (!existing.isEnabledByDefault && application.isEnabledByDefault)
                || (existing.isEnabledByDefault == application.isEnabledByDefault
                    && application.path.count < existing.path.count) {
                applicationsByID[application.preferenceID] = application
            }
        }

        return applicationsByID.values.sorted { left, right in
            if left.isEnabledByDefault != right.isEnabledByDefault {
                return left.isEnabledByDefault
            }
            return left.name.localizedStandardCompare(right.name) == .orderedAscending
        }
    }

    nonisolated private static func discoveredApplication(
        at url: URL,
        matchedExtensions: Set<String>
    ) -> ApplicationOption? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return nil }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        return ApplicationOption(
            preferenceID: "bundle.\(bundleIdentifier)",
            name: displayName,
            path: standardizedPath(url.path),
            fallbackSymbol: "app",
            isEnabledByDefault: false,
            supportedExtensions: matchedExtensions.sorted(),
            opensDirectories: false,
            menuIconData: cachedMenuIconData(for: url.path)
        )
    }

    nonisolated private static func isEligibleApplication(_ url: URL) -> Bool {
        let path = standardizedPath(url.path)
        guard path.hasSuffix(".app"),
              allowedApplicationRoots.contains(where: { path.hasPrefix($0 + "/") }),
              let bundle = Bundle(url: URL(fileURLWithPath: path)),
              let bundleIdentifier = bundle.bundleIdentifier,
              bundleIdentifier != FinderToolIdentifiers.mainAppBundleIdentifier,
              !excludedBundleIdentifiers.contains(bundleIdentifier),
              !plistFlag(bundle.object(forInfoDictionaryKey: "LSBackgroundOnly")),
              !plistFlag(bundle.object(forInfoDictionaryKey: "LSUIElement")) else {
            return false
        }
        return true
    }

    nonisolated private static var allowedApplicationRoots: [String] {
        [
            "/Applications",
            "/System/Applications",
            standardizedPath(
                FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Applications", isDirectory: true).path
            )
        ]
    }

    nonisolated private static func plistFlag(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return value == "1" || value.lowercased() == "true" }
        return false
    }

    nonisolated private static func cachedMenuIconData(for path: String) -> Data? {
        if let cached = iconCache[path] {
            return cached
        }

        let sourceImage = NSWorkspace.shared.icon(forFile: path)
        let pixelSize = NSSize(width: 36, height: 36)
        let thumbnail = NSImage(size: pixelSize)

        thumbnail.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(origin: .zero, size: pixelSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        thumbnail.unlockFocus()

        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

        let pngData = bitmap.representation(using: .png, properties: [:])
        iconCacheLock.lock()
        defer { iconCacheLock.unlock() }
        if let pngData {
            iconCache[path] = pngData
        }
        return pngData
    }

    nonisolated private static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

private enum FinderToolIdentifiers {
    static let mainAppBundleIdentifier = "com.wheat.FinderTools"
}
