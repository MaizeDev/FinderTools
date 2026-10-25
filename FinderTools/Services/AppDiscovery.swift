import AppKit
import UniformTypeIdentifiers

enum AppDiscovery {
    // Conversational AI apps can advertise broad document types even though
    // they are not useful general-purpose file editors/viewers.
    nonisolated private static let excludedBundleIdentifiers: Set<String> = [
        "com.alibaba.tongyi", // Qianwen / 千问
        "com.openai.chat",   // ChatGPT
        "com.openai.codex"   // ChatGPT Classic / Codex
    ]

    // These are the common file families FinderTools intentionally supports.
    // Launch Services supplies the matching apps; FinderTools does not walk
    // every installed .app bundle anymore.
    nonisolated private static let commonExtensions = [
        "txt", "md", "rtf", "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "csv",
        "json", "yaml", "yml", "xml", "html", "css", "js", "ts", "swift", "py", "java", "c", "h", "cpp",
        "jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "tiff",
        "mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv", "avi",
        "zip", "7z", "rar", "tar", "gz"
    ]

    nonisolated static func allApplications() -> [ApplicationMenuOption] {
        let curatedInstallations = CuratedApplicationCatalog.all.compactMap {
            curated -> (curated: CuratedApplication, path: String)? in
            guard let path = curated.resolvedPath else { return nil }
            return (curated, path)
        }
        // D-08：不同精选条目可能解析到同一路径（例如 Toolbox 与 /Applications 各一份），
        // 重复时保留先出现的条目，避免 `uniqueKeysWithValues` 崩溃。
        let curatedByPath = Dictionary(
            curatedInstallations.map {
                (standardizedPath($0.path), $0.curated)
            },
            uniquingKeysWith: { first, _ in first }
        )
        var extensionsByApplicationPath: [String: Set<String>] = [:]

        for fileExtension in commonExtensions {
            guard let contentType = UTType(filenameExtension: fileExtension) else { continue }

            for applicationURL in NSWorkspace.shared.urlsForApplications(toOpen: contentType)
            where isEligibleApplication(applicationURL) {
                extensionsByApplicationPath[
                    standardizedPath(applicationURL.path),
                    default: []
                ].insert(fileExtension)
            }
        }

        var applicationsByPath: [String: ApplicationMenuOption] = [:]
        for (path, matchedExtensions) in extensionsByApplicationPath {
            if let curated = curatedByPath[path] {
                applicationsByPath[path] = curated.option(
                    atPath: path,
                    matchedExtensions: matchedExtensions,
                    menuIconData: cachedMenuIconData(for: path)
                )
            } else if let discovered = discoveredApplication(
                at: URL(fileURLWithPath: path),
                matchedExtensions: matchedExtensions
            ) {
                applicationsByPath[path] = discovered
            }
        }

        // Terminal apps and other curated exceptions may not register as
        // document handlers, so retain them through this small explicit list.
        for installation in curatedInstallations {
            let path = standardizedPath(installation.path)
            if applicationsByPath[path] == nil {
                applicationsByPath[path] = installation.curated.option(
                    atPath: path,
                    matchedExtensions: [],
                    menuIconData: cachedMenuIconData(for: path)
                )
            }
        }

        var applicationsByID: [String: ApplicationMenuOption] = [:]
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
    ) -> ApplicationMenuOption? {
        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier else { return nil }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let capabilities = ApplicationCapabilities(bundle: bundle)

        return ApplicationMenuOption(
            preferenceID: "bundle.\(bundleIdentifier)",
            name: displayName,
            path: standardizedPath(url.path),
            fallbackSymbol: "app",
            isEnabledByDefault: false,
            supportedExtensions: matchedExtensions.sorted(),
            opensDirectories: capabilities.opensDirectories,
            supportedTypeIdentifiers: capabilities.supportedTypeIdentifiers,
            isBundleOpener: capabilities.isBundleOpener,
            menuIconData: cachedMenuIconData(for: url.path)
        )
    }

    nonisolated private static func isEligibleApplication(_ url: URL) -> Bool {
        let path = standardizedPath(url.path)
        guard path.hasSuffix(".app"),
              allowedApplicationRoots.contains(where: { path.hasPrefix($0 + "/") }),
              let bundle = Bundle(url: URL(fileURLWithPath: path)),
              let bundleIdentifier = bundle.bundleIdentifier,
              bundleIdentifier != "com.wheat.FinderTools",
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
                RealHome.url
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
        let sourceImage = NSWorkspace.shared.icon(forFile: path)
        let pixelSize = NSSize(width: 36, height: 36)

        // C-08：lockFocus 只在主线程安全且已弃用，改用离屏位图 + NSGraphicsContext，
        // 这样可以在后台任务里安全调用。
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        bitmap.size = pixelSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        sourceImage.draw(
            in: NSRect(origin: .zero, size: pixelSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        return bitmap.representation(using: .png, properties: [:])
    }

    nonisolated private static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
