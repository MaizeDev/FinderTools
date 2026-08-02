import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case createFiles
    case openWith
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .createFiles: "新建文件"
        case .openWith: "打开方式"
        case .permissions: "扩展权限"
        }
    }

    var systemImage: String {
        switch self {
        case .createFiles: "doc.badge.plus"
        case .openWith: "macwindow.on.rectangle"
        case .permissions: "checkmark.shield"
        }
    }

    var subtitle: String {
        switch self {
        case .createFiles: "管理右键新建菜单"
        case .openWith: "选择常用打开应用"
        case .permissions: "检查扩展与文件夹权限"
        }
    }
}
