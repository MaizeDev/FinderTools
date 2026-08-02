import SwiftUI

struct PageContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: 820, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        }
    }
}

struct SettingsRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 14) {
            leading
            Spacer(minLength: 20)
            trailing
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 66)
    }
}

struct MenuItemControls: View {
    let itemName: String
    let isAvailable: Bool

    @AppStorage private var isEnabled: Bool
    @AppStorage private var placement: FinderMenuPlacement

    init(
        itemName: String,
        enabledKey: String,
        placementKey: String,
        isAvailable: Bool = true
    ) {
        self.itemName = itemName
        self.isAvailable = isAvailable
        _isEnabled = AppStorage(
            wrappedValue: true,
            enabledKey,
            store: FinderMenuPreferences.store
        )
        _placement = AppStorage(
            wrappedValue: .submenu,
            placementKey,
            store: FinderMenuPreferences.store
        )
    }

    var body: some View {
        if isAvailable {
            HStack(spacing: 14) {
                Picker("\(itemName)的菜单位置", selection: $placement) {
                    ForEach(FinderMenuPlacement.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 154)
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.5)

                Toggle("启用\(itemName)", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .accessibilityLabel("启用\(itemName)")
            }
            .onChange(of: isEnabled) {
                FinderMenuPreferences.notifyExtension()
            }
            .onChange(of: placement) {
                FinderMenuPreferences.notifyExtension()
            }
        } else {
            AvailabilityBadge(isInstalled: false)
        }
    }
}

struct AvailabilityBadge: View {
    let isInstalled: Bool

    var body: some View {
        Label(
            isInstalled ? "已安装" : "未安装",
            systemImage: isInstalled ? "checkmark.circle.fill" : "minus.circle.fill"
        )
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(isInstalled ? .green : .secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            isInstalled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.1),
            in: Capsule()
        )
    }
}

struct InfoCard: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
