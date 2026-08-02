import SwiftUI

struct CreateFilesView: View {
    private let officeFileTypes = [
        FileTypeOption(id: "text", name: "纯文本文件", abbreviation: "TXT", symbol: "doc.plaintext", color: .gray, defaultEnabled: true),
        FileTypeOption(id: "word", name: "Word 文档", abbreviation: "DOCX", symbol: "doc.text", color: .blue, defaultEnabled: true),
        FileTypeOption(id: "excel", name: "Excel 表格", abbreviation: "XLSX", symbol: "tablecells", color: .green, defaultEnabled: true),
        FileTypeOption(id: "powerpoint", name: "PowerPoint 演示文稿", abbreviation: "PPTX", symbol: "rectangle.on.rectangle.angled", color: .orange, defaultEnabled: true),
        FileTypeOption(id: "markdown", name: "Markdown 文档", abbreviation: "MD", symbol: "text.document", color: .indigo, defaultEnabled: false),
        FileTypeOption(id: "richtext", name: "富文本文件", abbreviation: "RTF", symbol: "doc.richtext", color: .purple, defaultEnabled: false),
        FileTypeOption(id: "csv", name: "CSV 表格", abbreviation: "CSV", symbol: "tablecells.badge.ellipsis", color: .green, defaultEnabled: false)
    ]

    private let developerFileTypes = [
        FileTypeOption(id: "json", name: "JSON 数据文件", abbreviation: "JSON", symbol: "curlybraces", color: .orange, defaultEnabled: false),
        FileTypeOption(id: "yaml", name: "YAML 配置文件", abbreviation: "YAML", symbol: "list.bullet.rectangle", color: .pink, defaultEnabled: false),
        FileTypeOption(id: "html", name: "HTML 网页", abbreviation: "HTML", symbol: "globe", color: .blue, defaultEnabled: false),
        FileTypeOption(id: "css", name: "CSS 样式表", abbreviation: "CSS", symbol: "paintbrush", color: .cyan, defaultEnabled: false),
        FileTypeOption(id: "javascript", name: "JavaScript 文件", abbreviation: "JS", symbol: "curlybraces.square", color: .yellow, defaultEnabled: false),
        FileTypeOption(id: "swift", name: "Swift 源代码", abbreviation: "SWIFT", symbol: "swift", color: .orange, defaultEnabled: false),
        FileTypeOption(id: "python", name: "Python 源代码", abbreviation: "PY", symbol: "chevron.left.forwardslash.chevron.right", color: .blue, defaultEnabled: false)
    ]

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "新建文件",
                    subtitle: "每种文件都可以单独启用，并选择显示在一级或二级菜单。"
                )

                fileTypeSection(title: "日常办公", fileTypes: officeFileTypes)
                fileTypeSection(title: "软件开发", fileTypes: developerFileTypes)

                InfoCard(
                    icon: "lightbulb",
                    text: "开关关闭后，该文件类型不会出现在右键菜单；如果同名文件已经存在，会自动在名称后添加数字。"
                )
            }
        }
    }

    private func fileTypeSection(title: String, fileTypes: [FileTypeOption]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            SettingsCard {
                ForEach(Array(fileTypes.enumerated()), id: \.element.id) { index, fileType in
                    SettingsRow {
                        HStack(spacing: 14) {
                            Image(systemName: fileType.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(fileType.color)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(fileType.name)
                                    .font(.body.weight(.medium))
                                Text(fileType.abbreviation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } trailing: {
                        MenuItemControls(
                            itemName: fileType.name,
                            enabledKey: FinderMenuPreferences.enabledKey(
                                group: "newFile",
                                id: fileType.id
                            ),
                            placementKey: FinderMenuPreferences.placementKey(
                                group: "newFile",
                                id: fileType.id
                            ),
                            defaultEnabled: fileType.defaultEnabled
                        )
                    }

                    if index < fileTypes.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
        }
    }
}

private struct FileTypeOption {
    let id: String
    let name: String
    let abbreviation: String
    let symbol: String
    let color: Color
    let defaultEnabled: Bool
}
