import FinderSync
import SwiftUI

struct PermissionView: View {
    @State private var isEnabled = FIFinderSyncController.isExtensionEnabled
    @State private var authorizedFolders = FolderAccessManager.shared.authorizedFolders
    @State private var folderPendingRemoval: FolderRemovalRequest?

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
                            ForEach(Array(authorizedFolders.enumerated()), id: \.element.path) { index, folder in
                                AuthorizedFolderRow(folder: folder) {
                                    folderPendingRemoval = FolderRemovalRequest(folder: folder)
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
                    text: "FinderTools 只能使用列表中的文件夹及其子文件夹。你可以分别添加桌面、下载、文稿、影片等位置，不需要授权整个个人目录。"
                )

                Button("刷新状态") {
                    refreshState()
                }
                .controlSize(.small)
            }
        }
        .alert(item: $folderPendingRemoval) { request in
            Alert(
                title: Text("移除文件夹授权？"),
                message: Text("移除“\(request.folder.lastPathComponent)”后，FinderTools 将无法在这个文件夹及其子文件夹中执行操作。"),
                primaryButton: .destructive(Text("移除")) {
                    FolderAccessManager.shared.removeAuthorization(for: request.folder)
                    refreshState()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    private var folderCountDescription: String {
        authorizedFolders.isEmpty ? "尚未添加任何文件夹" : "共 \(authorizedFolders.count) 个，可单独添加或移除"
    }

    private func addFolder() {
        guard FolderAccessManager.shared.chooseFolder() != nil else { return }
        refreshState()
    }

    private func refreshState() {
        isEnabled = FIFinderSyncController.isExtensionEnabled
        authorizedFolders = FolderAccessManager.shared.authorizedFolders
    }
}

private struct AuthorizedFolderRow: View {
    let folder: URL
    let remove: () -> Void

    var body: some View {
        SettingsRow {
            HStack(spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(folderName)
                        .font(.body.weight(.medium))
                    Text(folder.path(percentEncoded: false))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .help(folder.path(percentEncoded: false))
                }
            }
        } trailing: {
            Button(role: .destructive, action: remove) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
            .help("移除这个文件夹的授权")
            .accessibilityLabel("移除 \(folderName) 的授权")
        }
    }

    private var folderName: String {
        FileManager.default.displayName(atPath: folder.path)
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
                Text("添加需要使用右键功能的文件夹，例如桌面或下载。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("添加第一个文件夹", action: addFolder)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
    }
}

private struct FolderRemovalRequest: Identifiable {
    let folder: URL

    var id: String { folder.standardizedFileURL.path }
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
