import AppKit
import Foundation

/// 右键“使用软件打开”里的 App 模型：主 App 与扩展共用（D-01）。
///
/// JSON 字段名（`preferenceID` / `name` / `path` / `fallbackSymbol` /
/// `isEnabledByDefault` / `supportedExtensions` / `opensDirectories` / `menuIconData`）
/// 不能改，扩展按这份结构解码主 App 广播的配置。
nonisolated struct ApplicationMenuOption: Identifiable, Codable, Sendable {
    let preferenceID: String
    let name: String
    let path: String
    let fallbackSymbol: String
    let isEnabledByDefault: Bool
    let supportedExtensions: [String]
    let opensDirectories: Bool
    /// C-02：编辑器类 App 能打开任意文件；没有扩展名的文件（Makefile、.gitignore）只显示这类 App。
    let opensAnyFile: Bool
    /// C-02：App 的 Info.plist 声明的文档类型（UTI），按 `UTType.conforms(to:)` 兜底匹配。
    let supportedTypeIdentifiers: [String]
    /// C-03：App 声明了包（package）类型的文档，可打开 `.app` / `.rtfd` 等包。
    let isBundleOpener: Bool
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

    /// 扩展构建菜单时用的兜底图标。
    var fallbackMenuIcon: NSImage? {
        NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: name)
    }

    init(
        preferenceID: String,
        name: String,
        path: String,
        fallbackSymbol: String,
        isEnabledByDefault: Bool = true,
        supportedExtensions: [String] = [],
        opensDirectories: Bool = false,
        opensAnyFile: Bool = false,
        supportedTypeIdentifiers: [String] = [],
        isBundleOpener: Bool = false,
        menuIconData: Data? = nil
    ) {
        self.preferenceID = preferenceID
        self.name = name
        self.path = path
        self.fallbackSymbol = fallbackSymbol
        self.isEnabledByDefault = isEnabledByDefault
        self.supportedExtensions = supportedExtensions
        self.opensDirectories = opensDirectories
        self.opensAnyFile = opensAnyFile
        self.supportedTypeIdentifiers = supportedTypeIdentifiers
        self.isBundleOpener = isBundleOpener
        self.menuIconData = menuIconData
    }

    /// 旧版本配置可能缺字段，解码时退回到默认值。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferenceID = try container.decode(String.self, forKey: .preferenceID)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        fallbackSymbol = try container.decode(String.self, forKey: .fallbackSymbol)
        isEnabledByDefault = try container.decodeIfPresent(
            Bool.self,
            forKey: .isEnabledByDefault
        ) ?? true
        supportedExtensions = try container.decodeIfPresent(
            [String].self,
            forKey: .supportedExtensions
        ) ?? []
        opensDirectories = try container.decodeIfPresent(
            Bool.self,
            forKey: .opensDirectories
        ) ?? false
        opensAnyFile = try container.decodeIfPresent(
            Bool.self,
            forKey: .opensAnyFile
        ) ?? false
        supportedTypeIdentifiers = try container.decodeIfPresent(
            [String].self,
            forKey: .supportedTypeIdentifiers
        ) ?? []
        isBundleOpener = try container.decodeIfPresent(
            Bool.self,
            forKey: .isBundleOpener
        ) ?? false
        menuIconData = try container.decodeIfPresent(Data.self, forKey: .menuIconData)
    }

    /// 扩展在收到主 App 的配置之前的兜底列表（与旧版一致：不含扩展名信息，
    /// 第 7 步起补上能力标记，旧缓存解码时缺字段会回退到 `false` / `[]`）。
    static let defaults = [
        ApplicationMenuOption(preferenceID: "textedit", name: "文本编辑", path: "/System/Applications/TextEdit.app", fallbackSymbol: "doc.text", opensAnyFile: true),
        ApplicationMenuOption(preferenceID: "preview", name: "预览", path: "/System/Applications/Preview.app", fallbackSymbol: "doc.richtext"),
        ApplicationMenuOption(preferenceID: "terminal", name: "终端", path: "/System/Applications/Utilities/Terminal.app", fallbackSymbol: "terminal", opensDirectories: true),
        ApplicationMenuOption(preferenceID: "iterm", name: "iTerm", path: "/Applications/iTerm.app", fallbackSymbol: "terminal", opensDirectories: true),
        ApplicationMenuOption(preferenceID: "vscode", name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", fallbackSymbol: "chevron.left.forwardslash.chevron.right", opensDirectories: true, opensAnyFile: true),
        ApplicationMenuOption(preferenceID: "cursor", name: "Cursor", path: "/Applications/Cursor.app", fallbackSymbol: "cursorarrow", opensDirectories: true, opensAnyFile: true),
        ApplicationMenuOption(preferenceID: "sublime", name: "Sublime Text", path: "/Applications/Sublime Text.app", fallbackSymbol: "text.alignleft", opensDirectories: true, opensAnyFile: true),
        ApplicationMenuOption(preferenceID: "bbedit", name: "BBEdit", path: "/Applications/BBEdit.app", fallbackSymbol: "pencil", opensAnyFile: true),
        ApplicationMenuOption(preferenceID: "typora", name: "Typora", path: "/Applications/Typora.app", fallbackSymbol: "textformat"),
        ApplicationMenuOption(preferenceID: "iina", name: "IINA", path: "/Applications/IINA.app", fallbackSymbol: "play.rectangle"),
        ApplicationMenuOption(preferenceID: "word", name: "Microsoft Word", path: "/Applications/Microsoft Word.app", fallbackSymbol: "doc.text"),
        ApplicationMenuOption(preferenceID: "excel", name: "Microsoft Excel", path: "/Applications/Microsoft Excel.app", fallbackSymbol: "tablecells"),
        ApplicationMenuOption(preferenceID: "powerpoint", name: "Microsoft PowerPoint", path: "/Applications/Microsoft PowerPoint.app", fallbackSymbol: "rectangle.on.rectangle.angled"),
        ApplicationMenuOption(preferenceID: "xcode", name: "Xcode", path: "/Applications/Xcode.app", fallbackSymbol: "hammer", opensDirectories: true, opensAnyFile: true)
    ]
}
