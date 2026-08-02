import SwiftUI

struct CreateFilesView: View {
    private let fileTypes = [
        (id: "text", name: "纯文本文件", abbreviation: "TXT", symbol: "doc.plaintext", color: Color.gray),
        (id: "word", name: "Word 文档", abbreviation: "DOCX", symbol: "doc.text", color: Color.blue),
        (id: "excel", name: "Excel 表格", abbreviation: "XLSX", symbol: "tablecells", color: Color.green),
        (id: "powerpoint", name: "PowerPoint 演示文稿", abbreviation: "PPTX", symbol: "rectangle.on.rectangle.angled", color: Color.orange)
    ]

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "新建文件",
                    subtitle: "每种文件都可以单独启用，并选择显示在一级或二级菜单。"
                )

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
                                )
                            )
                        }

                        if index < fileTypes.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }

                InfoCard(
                    icon: "lightbulb",
                    text: "开关关闭后，该文件类型不会出现在右键菜单；如果同名文件已经存在，会自动在名称后添加数字。"
                )
            }
        }
    }
}
