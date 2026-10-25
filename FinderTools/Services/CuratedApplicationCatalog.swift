import Foundation

/// 精选 App 的单一来源（C-02 / C-04）。
///
/// 精选 App 不只要出现在扩展名快照里，还要标出能力（能否打开文件夹、能否打开任意文件）。
/// JetBrains Toolbox 默认把 IDE 装在 `~/Applications`，所以路径候选同时覆盖
/// `/Applications` 与真实主目录下的 `Applications`（用 C-01 的 `RealHome`）。
nonisolated struct CuratedApplication: Sendable {
    let preferenceID: String
    let name: String
    let pathCandidates: [String]
    let fallbackSymbol: String
    let fallbackExtensions: [String]
    let opensDirectories: Bool
    let opensAnyFile: Bool

    init(
        preferenceID: String,
        name: String,
        path: String,
        fallbackSymbol: String,
        fallbackExtensions: [String] = [],
        opensDirectories: Bool = false,
        opensAnyFile: Bool = false
    ) {
        self.init(
            preferenceID: preferenceID,
            name: name,
            pathCandidates: [path],
            fallbackSymbol: fallbackSymbol,
            fallbackExtensions: fallbackExtensions,
            opensDirectories: opensDirectories,
            opensAnyFile: opensAnyFile
        )
    }

    init(
        preferenceID: String,
        name: String,
        pathCandidates: [String],
        fallbackSymbol: String,
        fallbackExtensions: [String] = [],
        opensDirectories: Bool = false,
        opensAnyFile: Bool = false
    ) {
        self.preferenceID = preferenceID
        self.name = name
        self.pathCandidates = pathCandidates
        self.fallbackSymbol = fallbackSymbol
        self.fallbackExtensions = fallbackExtensions
        self.opensDirectories = opensDirectories
        self.opensAnyFile = opensAnyFile
    }

    /// 候选路径里第一个真实存在的路径；都没装时返回 nil，不进入菜单。
    var resolvedPath: String? {
        pathCandidates.first { FileManager.default.fileExists(atPath: $0) }
    }

    /// 生成菜单模型。能力字段优先来自 App 自己的 Info.plist，精选标记只做兜底。
    func option(
        atPath path: String,
        matchedExtensions: Set<String>,
        menuIconData: Data?
    ) -> ApplicationMenuOption {
        let capabilities = ApplicationCapabilities.load(atPath: path)
        return ApplicationMenuOption(
            preferenceID: preferenceID,
            name: name,
            path: path,
            fallbackSymbol: fallbackSymbol,
            isEnabledByDefault: true,
            supportedExtensions: Array(
                matchedExtensions.union(fallbackExtensions)
            ).sorted(),
            opensDirectories: opensDirectories || (capabilities?.opensDirectories ?? false),
            opensAnyFile: opensAnyFile,
            supportedTypeIdentifiers: capabilities?.supportedTypeIdentifiers ?? [],
            isBundleOpener: capabilities?.isBundleOpener ?? false,
            menuIconData: menuIconData
        )
    }
}

nonisolated enum CuratedApplicationCatalog {
    /// `/Applications` 与真实主目录下的 `Applications`（JetBrains Toolbox 默认安装位置）。
    private static let applicationRoots = [
        "/Applications",
        URL(
            fileURLWithPath: RealHome.url
                .appendingPathComponent("Applications", isDirectory: true).path
        ).standardizedFileURL.path
    ]

    private static func installedPaths(named names: [String]) -> [String] {
        applicationRoots.flatMap { root in names.map { "\(root)/\($0)" } }
    }

    private static let textAndCodeExtensions = [
        "txt", "md", "rtf", "csv", "json", "yaml", "yml", "xml", "html", "css",
        "js", "ts", "swift", "py", "java", "c", "h", "cpp"
    ]

    static let all: [CuratedApplication] = [
        CuratedApplication(preferenceID: "textedit", name: "文本编辑", path: "/System/Applications/TextEdit.app", fallbackSymbol: "doc.text", fallbackExtensions: textAndCodeExtensions, opensAnyFile: true),
        CuratedApplication(preferenceID: "preview", name: "预览", path: "/System/Applications/Preview.app", fallbackSymbol: "doc.richtext", fallbackExtensions: ["pdf", "jpg", "jpeg", "png", "gif", "webp", "svg", "heic", "tiff"]),
        CuratedApplication(preferenceID: "terminal", name: "终端", path: "/System/Applications/Utilities/Terminal.app", fallbackSymbol: "terminal", opensDirectories: true),
        CuratedApplication(preferenceID: "iterm", name: "iTerm", path: "/Applications/iTerm.app", fallbackSymbol: "terminal", opensDirectories: true),
        CuratedApplication(preferenceID: "vscode", name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: textAndCodeExtensions, opensDirectories: true, opensAnyFile: true),
        CuratedApplication(preferenceID: "cursor", name: "Cursor", path: "/Applications/Cursor.app", fallbackSymbol: "cursorarrow", fallbackExtensions: textAndCodeExtensions, opensDirectories: true, opensAnyFile: true),
        CuratedApplication(preferenceID: "sublime", name: "Sublime Text", path: "/Applications/Sublime Text.app", fallbackSymbol: "text.alignleft", fallbackExtensions: textAndCodeExtensions, opensDirectories: true, opensAnyFile: true),
        CuratedApplication(preferenceID: "bbedit", name: "BBEdit", path: "/Applications/BBEdit.app", fallbackSymbol: "pencil", fallbackExtensions: textAndCodeExtensions, opensAnyFile: true),
        CuratedApplication(preferenceID: "typora", name: "Typora", path: "/Applications/Typora.app", fallbackSymbol: "textformat", fallbackExtensions: ["txt", "md", "html"]),
        CuratedApplication(preferenceID: "iina", name: "IINA", path: "/Applications/IINA.app", fallbackSymbol: "play.rectangle", fallbackExtensions: ["mp3", "m4a", "wav", "flac", "mp4", "mov", "mkv", "avi"]),
        CuratedApplication(preferenceID: "word", name: "Microsoft Word", path: "/Applications/Microsoft Word.app", fallbackSymbol: "doc.text", fallbackExtensions: ["doc", "docx", "rtf", "txt", "pdf"]),
        CuratedApplication(preferenceID: "excel", name: "Microsoft Excel", path: "/Applications/Microsoft Excel.app", fallbackSymbol: "tablecells", fallbackExtensions: ["xls", "xlsx", "csv"]),
        CuratedApplication(preferenceID: "powerpoint", name: "Microsoft PowerPoint", path: "/Applications/Microsoft PowerPoint.app", fallbackSymbol: "rectangle.on.rectangle.angled", fallbackExtensions: ["ppt", "pptx"]),
        CuratedApplication(preferenceID: "xcode", name: "Xcode", path: "/Applications/Xcode.app", fallbackSymbol: "hammer", fallbackExtensions: ["swift", "c", "h", "cpp", "java"], opensDirectories: true, opensAnyFile: true),

        // JetBrains Toolbox 系 IDE（C-04）：路径同时查 /Applications 与 ~/Applications。
        CuratedApplication(preferenceID: "intellij", name: "IntelliJ IDEA", pathCandidates: installedPaths(named: ["IntelliJ IDEA.app", "IntelliJ IDEA Ultimate.app", "IntelliJ IDEA CE.app", "IntelliJ IDEA Community Edition.app"]), fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: ["java", "kt", "kts", "groovy", "gradle", "xml", "properties", "json", "yaml", "md"], opensDirectories: true),
        CuratedApplication(preferenceID: "webstorm", name: "WebStorm", pathCandidates: installedPaths(named: ["WebStorm.app"]), fallbackSymbol: "globe", fallbackExtensions: ["js", "jsx", "ts", "tsx", "json", "html", "css", "scss", "less", "vue", "md"], opensDirectories: true),
        CuratedApplication(preferenceID: "pycharm", name: "PyCharm", pathCandidates: installedPaths(named: ["PyCharm.app", "PyCharm Professional.app", "PyCharm CE.app", "PyCharm Community Edition.app"]), fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: ["py", "pyw", "pyi", "ipynb", "html", "json", "yaml", "yml", "md", "txt", "toml"], opensDirectories: true),
        CuratedApplication(preferenceID: "androidstudio", name: "Android Studio", pathCandidates: installedPaths(named: ["Android Studio.app"]), fallbackSymbol: "hammer", fallbackExtensions: ["java", "kt", "kts", "gradle", "xml", "json", "md"], opensDirectories: true),
        CuratedApplication(preferenceID: "clion", name: "CLion", pathCandidates: installedPaths(named: ["CLion.app"]), fallbackSymbol: "hammer", fallbackExtensions: ["c", "h", "cc", "cpp", "cxx", "hpp", "hxx", "cmake", "txt", "md"], opensDirectories: true),
        CuratedApplication(preferenceID: "goland", name: "GoLand", pathCandidates: installedPaths(named: ["GoLand.app"]), fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: ["go", "mod", "sum", "yaml", "yml", "json", "md", "txt"], opensDirectories: true),
        CuratedApplication(preferenceID: "rider", name: "Rider", pathCandidates: installedPaths(named: ["Rider.app"]), fallbackSymbol: "hammer", fallbackExtensions: ["cs", "sln", "csproj", "fs", "fsproj"], opensDirectories: true),
        CuratedApplication(preferenceID: "datagrip", name: "DataGrip", pathCandidates: installedPaths(named: ["DataGrip.app"]), fallbackSymbol: "tablecells", fallbackExtensions: ["sql", "csv", "json", "xml", "yaml"], opensDirectories: true),
        CuratedApplication(preferenceID: "phpstorm", name: "PhpStorm", pathCandidates: installedPaths(named: ["PhpStorm.app"]), fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: ["php", "phtml", "js", "ts", "html", "css", "json"], opensDirectories: true),
        CuratedApplication(preferenceID: "rubymine", name: "RubyMine", pathCandidates: installedPaths(named: ["RubyMine.app"]), fallbackSymbol: "chevron.left.forwardslash.chevron.right", fallbackExtensions: ["rb", "erb", "rake", "yml", "yaml", "js", "html"], opensDirectories: true)
    ]
}
