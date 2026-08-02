import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem?

    init(selection: SidebarItem = .createFiles) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        HStack(spacing: 0) {
            
            SidebarView(selection: $selection)
                .frame(width: 268)

            Divider()

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar(removing: .title)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .overlay(alignment: .top) {
            Color.clear
                .frame(height: 48)
                .contentShape(.rect)
                .gesture(WindowDragGesture())
                .allowsWindowActivationEvents()
        }
        .frame(minWidth: 760, minHeight: 500)
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
}

#Preview("扩展权限") {
    ContentView(selection: .permissions)
        .frame(width: 900, height: 620)
}
