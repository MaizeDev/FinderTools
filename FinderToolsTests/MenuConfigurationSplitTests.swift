import XCTest
@testable import FinderTools

final class MenuConfigurationSplitTests: XCTestCase {
    private let application = ApplicationMenuOption(
        preferenceID: "vscode",
        name: "Visual Studio Code",
        path: "/Applications/Visual Studio Code.app",
        fallbackSymbol: "chevron.left.forwardslash.chevron.right",
        supportedExtensions: ["swift"],
        opensDirectories: true,
        opensAnyFile: true
    )

    private let authorizedFolderPaths = ["/Users/example/Desktop", "/Users/example/Downloads"]

    private func fullConfiguration(authorizedFolderPaths: [String]? = nil) -> MenuConfiguration {
        MenuConfiguration(
            newFiles: ["text": MenuItemSetting(isEnabled: true, placement: .submenu)],
            applications: ["vscode": MenuItemSetting(isEnabled: false, placement: .primary)],
            applicationOptions: [application],
            authorizedFolderPaths: authorizedFolderPaths
        )
    }

    /// C-06：设置段编码后不得再带 applicationOptions（图标），否则负载没有变小。
    /// C-05：授权文件夹路径是设置段的一部分，必须跟着设置段一起发。
    func testSettingsSegmentOmitsApplicationCatalog() throws {
        let data = try JSONEncoder().encode(
            fullConfiguration(authorizedFolderPaths: authorizedFolderPaths).removingApplicationOptions()
        )
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(
            Set(object.keys),
            ["newFiles", "applications", "authorizedFolderPaths"]
        )

        let decoded = try JSONDecoder().decode(MenuConfiguration.self, from: data)
        XCTAssertNil(decoded.applicationOptions)
        XCTAssertEqual(decoded.newFiles["text"]?.isEnabled, true)
        XCTAssertEqual(decoded.applications["vscode"]?.placement, .primary)
        XCTAssertEqual(decoded.authorizedFolderPaths, authorizedFolderPaths)
    }

    /// C-06：旧版整份配置到达时，要能拆成设置段 + 应用目录段。
    func testLegacyFullConfigurationSplitsIntoBothSegments() throws {
        let data = try JSONEncoder().encode(fullConfiguration())
        let legacy = try JSONDecoder().decode(MenuConfiguration.self, from: data)

        let settings = legacy.removingApplicationOptions()
        XCTAssertNil(settings.applicationOptions)
        XCTAssertEqual(settings.applications["vscode"]?.isEnabled, false)
        // 旧版配置没有这个字段，保持 nil，扩展据此判断“还不知道授权文件夹”。
        XCTAssertNil(settings.authorizedFolderPaths)

        let options = try XCTUnwrap(legacy.applicationOptions)
        XCTAssertEqual(options.map(\.preferenceID), ["vscode"])
        XCTAssertEqual(options.first?.supportedExtensions, ["swift"])
    }

    /// C-06：两段合并后必须还原成 `MenuBuilder` 需要的整份配置。
    /// C-05：拆分/合并都不得丢掉授权文件夹路径。
    func testMergingSegmentsRestoresMenuBuilderConfiguration() throws {
        let legacy = try JSONDecoder().decode(
            MenuConfiguration.self,
            from: try JSONEncoder().encode(
                fullConfiguration(authorizedFolderPaths: authorizedFolderPaths)
            )
        )

        let merged = legacy.removingApplicationOptions()
            .merging(applicationOptions: legacy.applicationOptions)

        XCTAssertEqual(merged.newFiles["text"]?.isEnabled, true)
        XCTAssertEqual(merged.applications["vscode"]?.placement, .primary)
        XCTAssertEqual(merged.applicationOptions?.first?.preferenceID, "vscode")
        XCTAssertEqual(merged.applicationSetting(for: "vscode").isEnabled, false)
        XCTAssertEqual(merged.authorizedFolderPaths, authorizedFolderPaths)
    }

    /// C-06：扩展的 `menuSettings` 键里没有 applicationOptions，
    /// 旧的解码路径（整份配置）也必须能读这份 JSON。
    func testSettingsPayloadIsReadableByTheLegacyDecoder() throws {
        let settingsData = try JSONEncoder().encode(
            fullConfiguration().removingApplicationOptions()
        )

        let decoded = try JSONDecoder().decode(MenuConfiguration.self, from: settingsData)

        XCTAssertEqual(decoded.newFiles.count, 1)
        XCTAssertEqual(decoded.applications.count, 1)
        XCTAssertNil(decoded.applicationOptions)
    }

    // MARK: - C-05 向后兼容

    /// 升级前的主 App / 扩展发来的 JSON 没有 `authorizedFolderPaths` 键，必须能解码成 nil。
    func testLegacyJSONWithoutAuthorizedFolderPathsDecodesAsNil() throws {
        let legacyJSON = #"{"newFiles":{},"applications":{},"applicationOptions":null}"#
        let decoded = try JSONDecoder().decode(
            MenuConfiguration.self,
            from: Data(legacyJSON.utf8)
        )

        XCTAssertNil(decoded.authorizedFolderPaths)
    }

    /// 新版主 App 没有任何授权文件夹时仍然显式发送空数组（区别于旧数据的 nil）。
    ///
    /// 第 19 步起扩展不再用这个字段限制菜单出现范围，但字段仍随协议保留：
    /// 编码形态与旧版本一致，升级/回滚时才不会丢配置。
    func testEmptyAuthorizedFolderListIsEncodedExplicitly() throws {
        let data = try JSONEncoder().encode(fullConfiguration(authorizedFolderPaths: []))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["authorizedFolderPaths"] as? [String], [])

        let decoded = try JSONDecoder().decode(MenuConfiguration.self, from: data)
        XCTAssertEqual(decoded.authorizedFolderPaths, [])
    }
}
