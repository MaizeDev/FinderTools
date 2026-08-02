import SwiftUI

struct OpenWithView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var applications: [ApplicationOption] = []
    @State private var searchText = ""
    @State private var isRefreshing = false
    @State private var lastRefreshDate: Date?

    private var filteredApplications: [ApplicationOption] {
        guard !searchText.isEmpty else { return applications }
        return applications.filter {
            $0.name.localizedStandardContains(searchText)
                || $0.path.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 20) {
                    PageHeader(
                        title: "打开方式",
                        subtitle: "仅显示可打开常见文件的软件；右键菜单会按所选文件类型自动匹配。"
                    )

                    Spacer()

                    Button {
                        refreshApplications()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }

                HStack(spacing: 10) {
                    TextField("搜索软件", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("已找到 \(applications.count) 个")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsCard {
                    if filteredApplications.isEmpty {
                        SettingsRow {
                            ContentUnavailableView(
                                searchText.isEmpty ? "没有找到软件" : "没有匹配的软件",
                                systemImage: "magnifyingglass",
                                description: Text(searchText.isEmpty ? "请点击刷新后再试。" : "请换一个关键词。")
                            )
                            .frame(maxWidth: .infinity)
                        } trailing: {
                            EmptyView()
                        }
                    } else {
                        ForEach(Array(filteredApplications.enumerated()), id: \.element.id) { index, application in
                            applicationRow(application)

                            if index < filteredApplications.count - 1 {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }

                SettingsCard {
                    SettingsRow {
                        HStack(spacing: 14) {
                            Image(systemName: "plus.app")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("选择其他软件…")
                                    .font(.body.weight(.medium))
                                Text("临时选择未加入菜单的软件")
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
                    text: "启动 FinderTools 时会刷新软件能力并缓存小图标；主窗口重新活跃超过 5 分钟也会更新。你仍可随时点击“刷新”。"
                )
            }
        }
        .task {
            applications = FinderMenuPreferences.installedApplications
            lastRefreshDate = FinderMenuPreferences.applicationCatalogRefreshDate

            guard applications.isEmpty
                    || lastRefreshDate.map({ Date().timeIntervalSince($0) >= 300 }) != false else {
                return
            }
            refreshApplications()
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active,
                  let lastRefreshDate,
                  Date().timeIntervalSince(lastRefreshDate) >= 300 else { return }
            refreshApplications()
        }
    }

    private func applicationRow(_ application: ApplicationOption) -> some View {
        SettingsRow {
            HStack(spacing: 14) {
                Image(nsImage: application.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(application.name)
                        .font(.body.weight(.medium))
                    Text(application.isEnabledByDefault ? "常用软件" : "已安装")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                defaultEnabled: application.isEnabledByDefault
            )
        }
    }

    private func refreshApplications() {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            let refreshedApplications = await Task.detached(priority: .userInitiated) {
                AppDiscovery.allApplications()
            }.value

            applications = refreshedApplications
            lastRefreshDate = Date()
            isRefreshing = false
            FinderMenuPreferences.updateApplications(refreshedApplications)
        }
    }
}
