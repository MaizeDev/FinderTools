import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem?

    init(selection: SidebarItem = .createFiles) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 第 20 步：登录项未开启时的提示条，放在内容区最上方。
            // 隐藏时不占空间，各页面内部布局不变。
            LaunchAtLoginHintBar(onOpenSettings: { selection = .general })

            // C-12：改用系统侧边栏与标准标题栏，去掉覆盖在内容上方的透明拖拽层，
            // 顶部 48pt 内的按钮（例如“打开方式”页的“刷新”）不再被吞点击。
            NavigationSplitView {
                SidebarView(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 268, max: 320)
            } detail: {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 760, minHeight: 500)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection ?? .createFiles {
        case .createFiles:
            CreateFilesView()
        case .openWith:
            OpenWithView()
        case .permissions:
            PermissionView()
        case .general:
            SettingsView()
        }
    }
}

#Preview("新建文件") {
    ContentView(selection: .createFiles)
        .frame(width: 900, height: 620)
}

#Preview("打开方式") {
    ContentView(selection: .openWith)
        .frame(width: 900, height: 620)
        .environment(ApplicationCatalog.shared)
}

#Preview("扩展权限") {
    ContentView(selection: .permissions)
        .frame(width: 900, height: 620)
}
