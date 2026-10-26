import AppKit
import Combine
import SwiftUI

/// 主窗口内容区顶部的提示条（第 20 步）：
/// 登录项未开启时提醒“右键菜单需要主 App 在运行”。
///
/// 独立成文件，不改变任何页面的内部布局；隐藏时不占空间。
/// “不再提示”写入 UserDefaults（`AppPreferences.hasDismissedLaunchAtLoginHintKey`）；
/// 在设置页或系统设置里开启登录项后，这里会收到通知并自动隐藏。
struct LaunchAtLoginHintBar: View {
    let onOpenSettings: () -> Void

    private let preferences = AppPreferences()

    @State private var isLoginItemEnabled: Bool
    @State private var isDismissed: Bool

    init(onOpenSettings: @escaping () -> Void) {
        self.onOpenSettings = onOpenSettings
        let preferences = AppPreferences()
        _isLoginItemEnabled = State(initialValue: LoginItemService.isEnabled)
        _isDismissed = State(initialValue: preferences.hasDismissedLaunchAtLoginHint)
    }

    var body: some View {
        Group {
            if !isLoginItemEnabled && !isDismissed {
                hintContent
            }
        }
        .task {
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 用户可能刚在系统设置里改了登录项，回到 App 时同步一次。
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: LoginItemService.statusDidChangeNotification)) { _ in
            // 在“通用”页开启/关闭登录项后立即同步。
            refresh()
        }
    }

    private var hintContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)

            Text("右键菜单需要 FinderTools 保持运行。建议在“通用”里开启“登录时自动启动”。")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Button("前往设置") {
                onOpenSettings()
            }
            .controlSize(.small)

            Button("不再提示") {
                preferences.hasDismissedLaunchAtLoginHint = true
                isDismissed = true
            }
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func refresh() {
        isLoginItemEnabled = LoginItemService.isEnabled
        isDismissed = preferences.hasDismissedLaunchAtLoginHint
    }
}
