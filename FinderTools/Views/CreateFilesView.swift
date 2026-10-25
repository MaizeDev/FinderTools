import SwiftUI

struct CreateFilesView: View {
    private var officeFileTypes: [NewFileType] {
        NewFileType.allCases.filter { $0.category == .office }
    }

    private var developerFileTypes: [NewFileType] {
        NewFileType.allCases.filter { $0.category == .developer }
    }

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

    private func fileTypeSection(title: String, fileTypes: [NewFileType]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            SettingsCard {
                ForEach(Array(fileTypes.enumerated()), id: \.element.id) { index, fileType in
                    SettingsRow {
                        HStack(spacing: 14) {
                            Image(systemName: fileType.systemImage)
                                .font(.system(size: 20))
                                .foregroundStyle(fileType.color)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(fileType.displayName)
                                    .font(.body.weight(.medium))
                                Text(fileType.abbreviation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } trailing: {
                        MenuItemControls(
                            itemName: fileType.displayName,
                            enabledKey: FinderMenuPreferences.enabledKey(
                                group: "newFile",
                                id: fileType.preferenceID
                            ),
                            placementKey: FinderMenuPreferences.placementKey(
                                group: "newFile",
                                id: fileType.preferenceID
                            ),
                            defaultEnabled: fileType.isEnabledByDefault
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
