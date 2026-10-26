import XCTest
@testable import FinderTools

/// 第 19 步：`AuthorizationLocationPolicy` 的单元测试。
///
/// 覆盖你指定的场景：`/tmp` 经符号链接落入 `/private`、`/Applications` 根与子文件夹、
/// `/Volumes` 根与某块盘、`/Users` 根与个人目录、大小写差异。
final class AuthorizationLocationPolicyTests: XCTestCase {
    private let personalHome = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    private let externalDiskFolder = URL(
        fileURLWithPath: "/Volumes/Backup/Projects",
        isDirectory: true
    )

    // MARK: - 系统目录子树

    func testTargetsInsideRestrictedSubtreesAreUnsupported() {
        let unsupportedTargets = [
            "/System",
            "/System/Applications/TextEdit.app",
            "/Library",
            "/Library/Preferences/com.apple.finder.plist",
            "/usr",
            "/usr/local/bin/tool",
            "/bin",
            "/bin/ls",
            "/sbin",
            "/private",
            "/private/tmp/file.txt",
            "/dev",
            "/cores",
            "/Network"
        ]

        for path in unsupportedTargets {
            XCTAssertFalse(
                AuthorizationLocationPolicy.isTargetSupported(URL(fileURLWithPath: path)),
                "\(path) 应被判为不支持"
            )
        }
    }

    func testSiblingOfRestrictedSubtreeIsSupported() {
        // 只是名字前缀相同（/System-old），不是 /System 的子目录。
        let sibling = URL(fileURLWithPath: "/System-old", isDirectory: true)
        XCTAssertTrue(AuthorizationLocationPolicy.isTargetSupported(sibling))
    }

    /// `/tmp`、`/var`、`/etc` 是 `/private/...` 的符号链接。
    ///
    /// macOS 27 的 Foundation 会把 `/private/tmp` 规范化为 `/tmp`（反向别名），
    /// 因此策略必须同时列出两边；这里验证两种写法都无法被操作。
    func testTmpAndPrivateTmpAreBothUnsupported() {
        let tmpURL = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let privateTmpURL = URL(fileURLWithPath: "/private/tmp", isDirectory: true)

        // 两种写法应被归一到同一个规范路径（本机实测是 "/tmp"；只要求两边一致）。
        XCTAssertEqual(
            PathContainment.canonicalURL(tmpURL).path,
            PathContainment.canonicalURL(privateTmpURL).path
        )

        XCTAssertFalse(AuthorizationLocationPolicy.isTargetSupported(tmpURL))
        XCTAssertFalse(AuthorizationLocationPolicy.isTargetSupported(privateTmpURL))
        XCTAssertFalse(
            AuthorizationLocationPolicy.isTargetSupported(
                tmpURL.appendingPathComponent("some-file.txt")
            )
        )
    }

    func testOtherPrivateAliasesAreUnsupported() {
        for path in ["/var", "/var/log", "/var/folders", "/etc", "/etc/hosts"] {
            XCTAssertFalse(
                AuthorizationLocationPolicy.isTargetSupported(URL(fileURLWithPath: path)),
                "\(path) 应被判为不支持"
            )
        }
    }

    // MARK: - /Applications：仅根

    func testApplicationsRootIsUnsupportedButSubfoldersAreSupported() {
        let applicationsRoot = URL(fileURLWithPath: "/Applications", isDirectory: true)
        XCTAssertFalse(AuthorizationLocationPolicy.isTargetSupported(applicationsRoot))
        XCTAssertFalse(AuthorizationLocationPolicy.canAuthorizeFolder(applicationsRoot))

        let applicationBundle = URL(
            fileURLWithPath: "/Applications/Visual Studio Code.app",
            isDirectory: true
        )
        XCTAssertTrue(AuthorizationLocationPolicy.isTargetSupported(applicationBundle))

        let utilitiesFolder = URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true)
        XCTAssertTrue(AuthorizationLocationPolicy.isTargetSupported(utilitiesFolder))
        XCTAssertTrue(AuthorizationLocationPolicy.canAuthorizeFolder(utilitiesFolder))
    }

    // MARK: - /Volumes：仅根

    func testVolumesRootCannotBeAuthorizedButDiskFolderCan() {
        let volumesRoot = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        // 根本身无法合法授权，因此也不能作为操作目标。
        XCTAssertFalse(AuthorizationLocationPolicy.isTargetSupported(volumesRoot))
        XCTAssertFalse(AuthorizationLocationPolicy.canAuthorizeFolder(volumesRoot))

        // 某块盘及其子目录仍然可以单独授权和操作。
        let diskRoot = URL(fileURLWithPath: "/Volumes/Backup", isDirectory: true)
        XCTAssertTrue(AuthorizationLocationPolicy.canAuthorizeFolder(diskRoot))
        XCTAssertTrue(AuthorizationLocationPolicy.isTargetSupported(diskRoot))
        XCTAssertTrue(AuthorizationLocationPolicy.canAuthorizeFolder(externalDiskFolder))
        XCTAssertTrue(AuthorizationLocationPolicy.isTargetSupported(externalDiskFolder))
    }

    // MARK: - /Users：仅根，个人目录本身可用

    func testUsersRootCannotBeAuthorizedButPersonalDirectoryCan() {
        let usersRoot = URL(fileURLWithPath: "/Users", isDirectory: true)
        XCTAssertFalse(AuthorizationLocationPolicy.isTargetSupported(usersRoot))
        XCTAssertFalse(AuthorizationLocationPolicy.canAuthorizeFolder(usersRoot))

        XCTAssertTrue(AuthorizationLocationPolicy.canAuthorizeFolder(personalHome))
        XCTAssertTrue(AuthorizationLocationPolicy.isTargetSupported(personalHome))
        XCTAssertTrue(
            AuthorizationLocationPolicy.isTargetSupported(
                personalHome.appendingPathComponent("Documents")
            )
        )
    }

    // MARK: - 根目录

    func testFileSystemRootIsNeverSupported() {
        let rootURL = URL(fileURLWithPath: "/", isDirectory: true)
        XCTAssertFalse(AuthorizationLocationPolicy.isTargetSupported(rootURL))
        XCTAssertFalse(AuthorizationLocationPolicy.canAuthorizeFolder(rootURL))
    }

    // MARK: - 个人目录提醒

    func testPersonalHomeDirectoryDetection() {
        XCTAssertTrue(
            AuthorizationLocationPolicy.isPersonalHomeDirectory(
                personalHome,
                homeDirectory: personalHome
            )
        )
        XCTAssertFalse(
            AuthorizationLocationPolicy.isPersonalHomeDirectory(
                personalHome.appendingPathComponent("Documents"),
                homeDirectory: personalHome
            )
        )
    }

    // MARK: - 其他位置

    func testOptAndRegularFoldersRemainSupported() {
        XCTAssertTrue(
            AuthorizationLocationPolicy.isTargetSupported(
                URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true)
            )
        )
        XCTAssertTrue(
            AuthorizationLocationPolicy.canAuthorizeFolder(
                URL(fileURLWithPath: "/opt/homebrew", isDirectory: true)
            )
        )
        XCTAssertTrue(
            AuthorizationLocationPolicy.isTargetSupported(
                URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)
            )
        )
    }

    func testMixedTargetsAreRejectedWhenAnyTargetIsUnsupported() {
        let supported = personalHome.appendingPathComponent("Desktop")
        let unsupported = URL(fileURLWithPath: "/Library/Preferences")

        XCTAssertTrue(AuthorizationLocationPolicy.areTargetsSupported([supported]))
        XCTAssertFalse(
            AuthorizationLocationPolicy.areTargetsSupported([supported, unsupported])
        )
    }

    // MARK: - 大小写差异

    /// 大小写规则跟随卷（D-09）：默认 APFS 不区分大小写，`/system` 等同于 `/System`；
    /// 区分大小写的卷上它们是两个不同路径。
    func testPathCasingFollowsVolumeRules() {
        let systemURL = URL(fileURLWithPath: "/System", isDirectory: true)
        let caseSensitive = (try? systemURL.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ))?.volumeSupportsCaseSensitiveNames ?? false

        XCTAssertEqual(
            AuthorizationLocationPolicy.isTargetSupported(
                URL(fileURLWithPath: "/system", isDirectory: true)
            ),
            caseSensitive,
            "不区分大小写的卷上 /system 应等同 /System（不支持）；区分大小写时应是另一个路径（支持）"
        )
        XCTAssertEqual(
            AuthorizationLocationPolicy.isTargetSupported(
                URL(fileURLWithPath: "/SYSTEM/Applications", isDirectory: true)
            ),
            caseSensitive
        )
        XCTAssertEqual(
            AuthorizationLocationPolicy.canAuthorizeFolder(
                URL(fileURLWithPath: "/volumes", isDirectory: true)
            ),
            caseSensitive
        )
        XCTAssertEqual(
            AuthorizationLocationPolicy.canAuthorizeFolder(
                URL(fileURLWithPath: "/users", isDirectory: true)
            ),
            caseSensitive
        )
    }
}
