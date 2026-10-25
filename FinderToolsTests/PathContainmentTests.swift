import XCTest
@testable import FinderTools

/// D-09：路径包含判断的规则（大小写、符号链接、路径组件边界）。
final class PathContainmentTests: XCTestCase {
    private let desktop = URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)

    func testAcceptsSamePathAndDescendants() {
        XCTAssertTrue(PathContainment.isInside(desktop, folder: desktop))
        XCTAssertTrue(
            PathContainment.isInside(
                desktop.appendingPathComponent("a/b.txt"),
                folder: desktop
            )
        )
    }

    func testRejectsSiblingWithSamePrefix() {
        XCTAssertFalse(
            PathContainment.isInside(
                URL(fileURLWithPath: "/Users/test/Desktop-old", isDirectory: true),
                folder: desktop
            )
        )
        XCTAssertFalse(
            PathContainment.isInside(
                URL(fileURLWithPath: "/Users/test", isDirectory: true),
                folder: desktop
            )
        )
    }

    func testCaseSensitivityFollowsVolume() throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("PathContainmentTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: base) }

        let upperCased = base.deletingLastPathComponent()
            .appendingPathComponent(base.lastPathComponent.uppercased(), isDirectory: true)
        let isCaseSensitive = (try? base.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ))?.volumeSupportsCaseSensitiveNames ?? false

        // APFS 默认不区分大小写：同一文件夹的大小写变体应视为同一个路径。
        XCTAssertEqual(PathContainment.isInside(upperCased, folder: base), !isCaseSensitive)
    }

    func testResolvesSymbolicLinks() throws {
        let fileManager = FileManager.default
        let base = fileManager.temporaryDirectory
            .appendingPathComponent("PathContainmentTests-\(UUID().uuidString)", isDirectory: true)
        let realFolder = base.appendingPathComponent("real", isDirectory: true)
        try fileManager.createDirectory(at: realFolder, withIntermediateDirectories: true)
        // 目标必须真实存在，`resolvingSymlinksInPath()` 才会展开路径中的符号链接。
        try Data().write(to: realFolder.appendingPathComponent("a.txt"))
        defer { try? fileManager.removeItem(at: base) }

        let link = base.appendingPathComponent("link", isDirectory: true)
        try fileManager.createSymbolicLink(at: link, withDestinationURL: realFolder)

        // 通过符号链接访问，等价于直接访问真实目录。
        XCTAssertTrue(PathContainment.isInside(link.appendingPathComponent("a.txt"), folder: realFolder))
        XCTAssertTrue(PathContainment.areEquivalent(link, realFolder))
    }

    func testEquivalentIgnoresStandardization() {
        let messy = URL(fileURLWithPath: "/Users/test/Desktop/../Desktop", isDirectory: true)
        XCTAssertTrue(PathContainment.areEquivalent(messy, desktop))
        XCTAssertFalse(
            PathContainment.areEquivalent(
                desktop,
                desktop.appendingPathComponent("sub", isDirectory: true)
            )
        )
    }
}
