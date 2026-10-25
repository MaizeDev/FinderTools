import AppKit
import SwiftUI

/// 新建文件的类型：主 App（设置页 / 文件创建）与 Finder 扩展（右键菜单）共用的唯一来源。
///
/// `rawValue` 同时也是右键菜单项的 tag，**case 顺序不能调整**。
nonisolated enum NewFileType: Int, CaseIterable, Identifiable, Sendable {
    case text
    case word
    case excel
    case powerPoint
    case markdown
    case richText
    case csv
    case json
    case yaml
    case html
    case css
    case javaScript
    case swift
    case python

    /// 设置页里的分组。
    enum Category: Sendable {
        case office
        case developer
    }

    var id: String { preferenceID }

    /// 设置项 id，同时是 UserDefaults 键的一部分，不能改。
    var preferenceID: String {
        switch self {
        case .text: "text"
        case .word: "word"
        case .excel: "excel"
        case .powerPoint: "powerpoint"
        case .markdown: "markdown"
        case .richText: "richtext"
        case .csv: "csv"
        case .json: "json"
        case .yaml: "yaml"
        case .html: "html"
        case .css: "css"
        case .javaScript: "javascript"
        case .swift: "swift"
        case .python: "python"
        }
    }

    var category: Category {
        switch self {
        case .text, .word, .excel, .powerPoint, .markdown, .richText, .csv:
            .office
        case .json, .yaml, .html, .css, .javaScript, .swift, .python:
            .developer
        }
    }

    var displayName: String {
        switch self {
        case .text: "纯文本文件"
        case .word: "Word 文档"
        case .excel: "Excel 表格"
        case .powerPoint: "PowerPoint 演示文稿"
        case .markdown: "Markdown 文档"
        case .richText: "富文本文件"
        case .csv: "CSV 表格"
        case .json: "JSON 数据文件"
        case .yaml: "YAML 配置文件"
        case .html: "HTML 网页"
        case .css: "CSS 样式表"
        case .javaScript: "JavaScript 文件"
        case .swift: "Swift 源代码"
        case .python: "Python 源代码"
        }
    }

    var abbreviation: String {
        fileExtension.uppercased()
    }

    /// 右键菜单里的名称。
    var menuTitle: String {
        "未命名.\(fileExtension)"
    }

    var fileExtension: String {
        switch self {
        case .text: "txt"
        case .word: "docx"
        case .excel: "xlsx"
        case .powerPoint: "pptx"
        case .markdown: "md"
        case .richText: "rtf"
        case .csv: "csv"
        case .json: "json"
        case .yaml: "yaml"
        case .html: "html"
        case .css: "css"
        case .javaScript: "js"
        case .swift: "swift"
        case .python: "py"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "doc.plaintext"
        case .word: "doc.text"
        case .excel: "tablecells"
        case .powerPoint: "rectangle.on.rectangle.angled"
        case .markdown: "text.document"
        case .richText: "doc.richtext"
        case .csv: "tablecells.badge.ellipsis"
        case .json: "curlybraces"
        case .yaml: "list.bullet.rectangle"
        case .html: "globe"
        case .css: "paintbrush"
        case .javaScript: "curlybraces.square"
        case .swift: "swift"
        case .python: "chevron.left.forwardslash.chevron.right"
        }
    }

    /// 右键菜单里的图标颜色。
    var menuColor: NSColor {
        switch self {
        case .text: .systemGray
        case .word: .systemBlue
        case .excel: .systemGreen
        case .powerPoint: .systemRed
        case .markdown: .systemIndigo
        case .richText: .systemPurple
        case .csv: .systemTeal
        case .json: .systemOrange
        case .yaml: .systemPink
        case .html: .systemBlue
        case .css: .systemCyan
        case .javaScript: .systemYellow
        case .swift: .systemOrange
        case .python: .systemBlue
        }
    }

    /// 设置页里的图标颜色。
    var color: Color {
        switch self {
        case .text: .gray
        case .word: .blue
        case .excel: .green
        case .powerPoint: .orange
        case .markdown: .indigo
        case .richText: .purple
        case .csv: .green
        case .json: .orange
        case .yaml: .pink
        case .html: .blue
        case .css: .cyan
        case .javaScript: .yellow
        case .swift: .orange
        case .python: .blue
        }
    }

    var isEnabledByDefault: Bool {
        switch self {
        case .text, .word, .excel, .powerPoint: true
        default: false
        }
    }

    /// Office 文件用主 App Resources 里的空白模板复制，其余写初始文本。
    var usesBlankTemplate: Bool {
        switch self {
        case .word, .excel, .powerPoint: true
        default: false
        }
    }

    var initialText: String {
        switch self {
        case .markdown: "# 未命名\n"
        case .richText: "{\\rtf1\\ansi\n}"
        case .json: "{\n}\n"
        case .yaml: "---\n"
        case .html:
            """
            <!doctype html>
            <html lang="zh-CN">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>未命名</title>
            </head>
            <body>

            </body>
            </html>

            """
        case .swift: "import Foundation\n\n"
        default: ""
        }
    }

    init?(fileExtension: String) {
        let normalized = fileExtension.lowercased()
        guard let type = Self.allCases.first(where: { $0.fileExtension == normalized }) else {
            return nil
        }
        self = type
    }
}
