import AppKit

struct ApplicationOption: Identifiable {
    let preferenceID: String
    let name: String
    let path: String
    let fallbackSymbol: String

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }
    var isInstalled: Bool { FileManager.default.fileExists(atPath: path) }

    var icon: NSImage {
        if isInstalled {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: name)
            ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: name)!
    }
}

enum AppDiscovery {
    static let applicationOptions = [
        ApplicationOption(preferenceID: "textedit", name: "文本编辑", path: "/System/Applications/TextEdit.app", fallbackSymbol: "doc.text"),
        ApplicationOption(preferenceID: "preview", name: "预览", path: "/System/Applications/Preview.app", fallbackSymbol: "doc.richtext"),
        ApplicationOption(preferenceID: "terminal", name: "终端", path: "/System/Applications/Utilities/Terminal.app", fallbackSymbol: "terminal"),
        ApplicationOption(preferenceID: "iterm", name: "iTerm", path: "/Applications/iTerm.app", fallbackSymbol: "terminal"),
        ApplicationOption(preferenceID: "vscode", name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", fallbackSymbol: "chevron.left.forwardslash.chevron.right"),
        ApplicationOption(preferenceID: "cursor", name: "Cursor", path: "/Applications/Cursor.app", fallbackSymbol: "cursorarrow"),
        ApplicationOption(preferenceID: "sublime", name: "Sublime Text", path: "/Applications/Sublime Text.app", fallbackSymbol: "text.alignleft"),
        ApplicationOption(preferenceID: "bbedit", name: "BBEdit", path: "/Applications/BBEdit.app", fallbackSymbol: "pencil"),
        ApplicationOption(preferenceID: "typora", name: "Typora", path: "/Applications/Typora.app", fallbackSymbol: "textformat"),
        ApplicationOption(preferenceID: "iina", name: "IINA", path: "/Applications/IINA.app", fallbackSymbol: "play.rectangle"),
        ApplicationOption(preferenceID: "word", name: "Microsoft Word", path: "/Applications/Microsoft Word.app", fallbackSymbol: "doc.text"),
        ApplicationOption(preferenceID: "excel", name: "Microsoft Excel", path: "/Applications/Microsoft Excel.app", fallbackSymbol: "tablecells"),
        ApplicationOption(preferenceID: "powerpoint", name: "Microsoft PowerPoint", path: "/Applications/Microsoft PowerPoint.app", fallbackSymbol: "rectangle.on.rectangle.angled"),
        ApplicationOption(preferenceID: "xcode", name: "Xcode", path: "/Applications/Xcode.app", fallbackSymbol: "hammer")
    ]

    static func allApplications() -> [ApplicationOption] {
        applicationOptions
    }
}
