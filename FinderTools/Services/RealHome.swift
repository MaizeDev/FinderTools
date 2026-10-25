import Darwin
import Foundation

/// 用户真实主目录。
///
/// 沙盒 App 里的 `FileManager.default.homeDirectoryForCurrentUser` 指向容器目录
/// （`~/Library/Containers/<bundle-id>/Data`），会漏掉 `~/Applications` 里安装的 App，
/// 也会让授权面板从错误的目录开始。这里改用 POSIX 账户信息取真实主目录，
/// 不做文件系统访问。
enum RealHome {
    /// 用户真实主目录。
    ///
    /// 主 App target 默认 `MainActor` 隔离，这里显式标 `nonisolated`，
    /// 方便 `AppDiscovery` 等非隔离代码使用。取不到账户信息时退回 `NSHomeDirectory()`。
    nonisolated static var url: URL {
        guard let homeDirectory = getpwuid(getuid())?.pointee.pw_dir else {
            return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        }
        return URL(fileURLWithPath: String(cString: homeDirectory), isDirectory: true)
    }
}
