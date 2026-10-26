import AppKit
import Combine
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferences.hideDockIconAfterLastWindowClosedKey)
    private var hideDockIconAfterLastWindowClosed = false

    @State private var launchAtLogin = LoginItemService.isEnabled
    @State private var launchAtLoginRequiresApproval = LoginItemService.requiresApproval
    @State private var launchAtLoginError: String?

    var body: some View {
        PageContainer {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "通用",
                    subtitle: "调整 FinderTools 的窗口、后台运行与启动方式。"
                )

                SettingsSection(title: "窗口与 Dock") {
                    SettingsRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("关闭窗口后隐藏 Dock 图标")
                                .font(.body.weight(.medium))
                            Text("关闭最后一个主窗口后，FinderTools 继续在后台运行，Dock 与应用切换器里都不再显示；右键菜单和 Finder 动作照常可用。再从“应用程序”或 Spotlight 打开 FinderTools，窗口与 Dock 图标会恢复。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } trailing: {
                        Toggle("关闭窗口后隐藏 Dock 图标", isOn: $hideDockIconAfterLastWindowClosed)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel("关闭窗口后隐藏 Dock 图标")
                    }
                }

                SettingsSection(title: "启动与退出") {
                    SettingsRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("登录时自动启动 FinderTools")
                                .font(.body.weight(.medium))
                            Text("登录后自动在后台启动，不弹主窗口、不显示 Dock 图标，右键菜单随即可用。关闭后，重启电脑需要手动打开一次 FinderTools，右键菜单才会出现。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } trailing: {
                        Toggle("登录时自动启动 FinderTools", isOn: launchAtLoginBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityLabel("登录时自动启动 FinderTools")
                    }

                    if let launchAtLoginError {
                        Divider()
                        LoginItemNotice(message: launchAtLoginError, isError: true)
                    } else if launchAtLoginRequiresApproval {
                        Divider()
                        LoginItemNotice(
                            message: "登录项已注册，但还需要你在系统设置中允许它登录时启动。",
                            isError: false
                        )
                    }

                    Divider()

                    SettingsRow {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("退出 FinderTools")
                                .font(.body.weight(.medium))
                            Text("完全退出后台进程（等同 ⌘Q）。退出后右键菜单消失，需要重新打开 FinderTools 才能恢复。隐藏 Dock 图标时，可先打开主窗口再按 ⌘Q，或在这里退出。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } trailing: {
                        Button("退出 FinderTools") {
                            NSApplication.shared.terminate(nil)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                InfoCard(
                    icon: "menubar.rectangle",
                    text: "Finder 右键菜单由扩展提供，但需要 FinderTools 主 App 在后台运行；关闭窗口不会退出 App。未开启“登录时自动启动”时，主窗口顶部会显示提示条。"
                )
            }
        }
        .onAppear {
            refreshLaunchAtLoginState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLoginState()
        }
        .onReceive(NotificationCenter.default.publisher(for: LoginItemService.statusDidChangeNotification)) { _ in
            refreshLaunchAtLoginState()
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { updateLaunchAtLogin($0) }
        )
    }

    private func refreshLaunchAtLoginState() {
        launchAtLogin = LoginItemService.isEnabled
        launchAtLoginRequiresApproval = LoginItemService.requiresApproval
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            try LoginItemService.setEnabled(enabled)
            launchAtLoginError = nil
        } catch let error as LoginItemService.ActionError {
            launchAtLoginError = error.userMessage
        } catch {
            launchAtLoginError = "更新登录项失败：\(error.localizedDescription)"
        }
        refreshLaunchAtLoginState()
    }
}

/// 登录项状态提示 + “打开登录项设置”。仅用于“启动与退出”分区。
private struct LoginItemNotice: View {
    let message: String
    let isError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                message,
                systemImage: isError
                    ? "exclamationmark.triangle.fill"
                    : "exclamationmark.circle.fill"
            )
            .font(.callout)
            .foregroundStyle(isError ? Color.red : Color.orange)
            .fixedSize(horizontal: false, vertical: true)

            Button("打开登录项设置") {
                LoginItemService.openSystemSettingsLoginItems()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

/// 页面内的一个设置分区。第 20 步在同一页追加了“启动与退出”分区，
/// 新增分区时只需再写一个 `SettingsSection`，不用改动现有结构。
private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            SettingsCard {
                content
            }
        }
    }
}

#Preview("通用") {
    SettingsView()
        .frame(width: 900, height: 620)
}
