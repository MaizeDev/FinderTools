import AppKit
import Combine
import FinderSync
import SwiftUI

struct PermissionView: View {
    @State private var isEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var authorizedFolders: [AuthorizedFolder] = []
    @State private var folderPendingRemoval: AuthorizedFolder?

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "扩展权限",
                    subtitle: "管理访达扩展，以及 FinderTools 可以使用的文件夹。"
                )

                SettingsCard {
                    SettingsRow {
                        PermissionStatus(
                            symbol: isEnabled ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                            color: isEnabled ? .green : .orange,
                            title: isEnabled ? "访达扩展已启用" : "访达扩展尚未启用",
                            detail: isEnabled ? "现在可以在访达中使用右键菜单。" : "请打开扩展管理并启用 FinderTools。"
                        )
                    } trailing: {
                        Button("打开扩展管理") {
                            FIFinderSyncController.showExtensionManagementInterface()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("已授权的文件夹")
                                .font(.headline)
                            Text(folderCountDescription)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            addFolder()
                        } label: {
                            Label("添加文件夹", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    SettingsCard {
                        if authorizedFolders.isEmpty {
                            EmptyFolderState {
                                addFolder()
                            }
                        } else {
                            ForEach(Array(authorizedFolders.enumerated()), id: \.element.id) { index, folder in
                                AuthorizedFolderRow(folder: folder) {
                                    folderPendingRemoval = folder
                                }

                                if index < authorizedFolders.count - 1 {
                                    Divider().padding(.leading, 68)
                                }
                            }
                        }
                    }
                }

                InfoCard(
                    icon: "lock.shield",
                    text: "FinderTools 的右键菜单只会在列表中的文件夹及其子文件夹里出现，也只能在这些位置执行操作。移除某个文件夹后，该位置的菜单也会消失；没有授权文件夹时访达里不会出现 FinderTools 菜单。你可以分别添加桌面、下载、文稿、影片等位置，不需要授权整个个人目录。"
                )

                Button("刷新状态") {
                    refreshState()
                }
                .controlSize(.small)
            }
        }
        .task {
            refreshState()
        }
        // D-05：从系统设置（扩展管理）切回来、或 App 重新激活时自动刷新，
        // 不再需要手动点“刷新状态”。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshState()
        }
        .alert(
            "移除文件夹授权？",
            isPresented: isRemovalAlertPresented,
            presenting: folderPendingRemoval
        ) { folder in
            Button("移除", role: .destructive) {
                FolderAccessManager.shared.removeAuthorization(for: folder)
                refreshState()
            }
            Button("取消", role: .cancel) {}
        } message: { folder in
            Text("移除“\(folder.displayName)”后，FinderTools 将无法在这个文件夹及其子文件夹中执行操作。")
        }
    }

    private var folderCountDescription: String {
        guard !authorizedFolders.isEmpty else { return "尚未添加任何文件夹" }

        let unavailableCount = authorizedFolders.filter { !$0.isAvailable }.count
        if unavailableCount == 0 {
            return "共 \(authorizedFolders.count) 个，可单独添加或移除"
        }
        return "共 \(authorizedFolders.count) 个，其中 \(unavailableCount) 个暂时不可用"
    }

    /// C-10：新式 `alert` 需要 `Bool` 绑定；关闭对话框时清掉待移除的文件夹。
    private var isRemovalAlertPresented: Binding<Bool> {
        Binding(
            get: { folderPendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    folderPendingRemoval = nil
                }
            }
        )
    }

    private func addFolder() {
        guard FolderAccessManager.shared.chooseFolder() != nil else { return }
        refreshState()
    }

    /// 只有这里会触发迁移/重建书签（会写 UserDefaults）；读取本身不写盘。
    /// 调用时机：页面出现（`.task`）、点“刷新状态”、添加或移除授权之后。
    private func refreshState() {
        FolderAccessManager.shared.refreshAuthorizations()
        isEnabled = FIFinderSyncController.isExtensionEnabled
        authorizedFolders = FolderAccessManager.shared.authorizedFolders
    }
}

private struct AuthorizedFolderRow: View {
    let folder: AuthorizedFolder
    let remove: () -> Void

    var body: some View {
        SettingsRow {
            HStack(spacing: 14) {
                Image(systemName: folder.isAvailable ? "folder.fill" : "folder.badge.questionmark")
                    .font(.system(size: 24))
                    .foregroundStyle(folder.isAvailable ? .blue : .orange)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(folder.displayName)
                            .font(.body.weight(.medium))

                        if !folder.isAvailable {
                            UnavailableBadge()
                        }
                    }

                    Text(folder.pathDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folder.pathDescription)
                }
            }
        } trailing: {
            Button(role: .destructive, action: remove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("移除这个文件夹的授权")
            .accessibilityLabel("移除 \(folder.displayName) 的授权")
        }
    }
}

private struct UnavailableBadge: View {
    var body: some View {
        Text("不可用")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.12), in: Capsule())
            .help("当前无法访问这个文件夹：外置硬盘可能未挂载，或文件夹已被移动/改名。插回硬盘或恢复文件夹后会自动恢复。")
    }
}

private struct EmptyFolderState: View {
    let addFolder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("还没有授权文件夹")
                    .font(.body.weight(.semibold))
                Text("右键菜单只会出现在已授权的文件夹里。请先添加一个文件夹（例如桌面或下载）；没有授权文件夹时，访达里不会出现 FinderTools 菜单。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("添加第一个文件夹", action: addFolder)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
    }
}

private struct PermissionStatus: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(color)
                .frame(width: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
