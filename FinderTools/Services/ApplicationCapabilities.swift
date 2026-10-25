import Foundation
import UniformTypeIdentifiers

/// 从 App 的 Info.plist 读取“它能打开什么”（C-02 / C-04）。
///
/// 只使用可确认的官方键：
/// - `CFBundleDocumentTypes[].LSItemContentTypes`：声明的文档类型（UTI）；
/// - `CFBundleDocumentTypes[].CFBundleTypeExtensions`：声明的扩展名（转换成系统已知的 UTI）；
/// - `CFBundleDocumentTypes[].LSTypeIsPackage`：该文档类型是包（package）。
///
/// 不根据 App 名字或名单猜能力；JetBrains 这类没有声明文件夹类型的 App 由
/// `AppDiscovery` 的精选列表兜底。
nonisolated struct ApplicationCapabilities: Sendable {
    let supportedTypeIdentifiers: [String]
    let opensDirectories: Bool
    let isBundleOpener: Bool

    init(bundle: Bundle) {
        let documentTypes = bundle.object(forInfoDictionaryKey: "CFBundleDocumentTypes")
            as? [[String: Any]] ?? []
        var identifiers: Set<String> = []
        var declaresFolder = false
        var declaresPackage = false

        for documentType in documentTypes {
            if let contentTypes = documentType["LSItemContentTypes"] as? [String] {
                for identifier in contentTypes {
                    identifiers.insert(identifier)
                    guard let type = UTType(identifier) else { continue }
                    if type.conforms(to: .folder) || type.conforms(to: .directory) {
                        declaresFolder = true
                    }
                    if type.conforms(to: .package) {
                        declaresPackage = true
                    }
                }
            }

            if let extensions = documentType["CFBundleTypeExtensions"] as? [String] {
                for fileExtension in extensions where !fileExtension.isEmpty {
                    guard let type = UTType(filenameExtension: fileExtension) else { continue }
                    // 跳过系统现造的动态类型（dyn.*）：它不保证和选中项解析出的类型一致。
                    guard !type.identifier.hasPrefix("dyn.") else { continue }
                    identifiers.insert(type.identifier)
                }
            }

            if Self.plistFlag(documentType["LSTypeIsPackage"]) {
                declaresPackage = true
            }
        }

        supportedTypeIdentifiers = identifiers.sorted()
        opensDirectories = declaresFolder
        isBundleOpener = declaresPackage
    }

    static func load(atPath path: String) -> ApplicationCapabilities? {
        guard let bundle = Bundle(url: URL(fileURLWithPath: path, isDirectory: true)) else {
            return nil
        }
        return ApplicationCapabilities(bundle: bundle)
    }

    private static func plistFlag(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return value == "1" || value.lowercased() == "true" }
        return false
    }
}
