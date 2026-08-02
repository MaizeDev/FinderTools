import SwiftUI

struct OpenWithView: View {
    private let applications = AppDiscovery.allApplications()

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "打开方式",
                    subtitle: "每个软件都可以单独启用，并选择显示在一级或二级菜单。"
                )

                SettingsCard {
                    ForEach(Array(applications.enumerated()), id: \.element.id) { index, application in
                        applicationRow(application)

                        Divider().padding(.leading, 60)
                    }

                    SettingsRow {
                        HStack(spacing: 14) {
                            Image(systemName: "plus.app")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("选择其他软件…")
                                    .font(.body.weight(.medium))
                                Text("手动选择其他应用")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } trailing: {
                        MenuItemControls(
                            itemName: "选择其他软件",
                            enabledKey: FinderMenuPreferences.enabledKey(
                                group: "application",
                                id: "other"
                            ),
                            placementKey: FinderMenuPreferences.placementKey(
                                group: "application",
                                id: "other"
                            )
                        )
                    }
                }

                InfoCard(
                    icon: "info.circle",
                    text: "未安装的软件不会出现在右键菜单；安装后会自动恢复为可设置状态。"
                )
            }
        }
    }

    private func applicationRow(_ application: ApplicationOption) -> some View {
        SettingsRow {
            HStack(spacing: 14) {
                Image(nsImage: application.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .grayscale(application.isInstalled ? 0 : 1)
                    .opacity(application.isInstalled ? 1 : 0.35)

                Text(application.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(application.isInstalled ? .primary : .tertiary)
            }
        } trailing: {
            MenuItemControls(
                itemName: application.name,
                enabledKey: FinderMenuPreferences.enabledKey(
                    group: "application",
                    id: application.preferenceID
                ),
                placementKey: FinderMenuPreferences.placementKey(
                    group: "application",
                    id: application.preferenceID
                ),
                isAvailable: application.isInstalled
            )
        }
    }
}
