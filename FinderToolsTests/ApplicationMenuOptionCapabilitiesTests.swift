import XCTest
@testable import FinderTools

final class ApplicationMenuOptionCapabilitiesTests: XCTestCase {
    func testLegacyConfigurationWithoutCapabilityFieldsStillDecodes() throws {
        // 旧版主 App 广播的 JSON：没有第 7 步新增的三个能力字段。
        let legacyJSON = """
        [{
            "preferenceID": "vscode",
            "name": "Visual Studio Code",
            "path": "/Applications/Visual Studio Code.app",
            "fallbackSymbol": "chevron.left.forwardslash.chevron.right",
            "isEnabledByDefault": true,
            "supportedExtensions": ["ts", "tsx"],
            "opensDirectories": true
        }]
        """
        let applications = try JSONDecoder().decode(
            [ApplicationMenuOption].self,
            from: Data(legacyJSON.utf8)
        )

        let application = try XCTUnwrap(applications.first)
        XCTAssertEqual(application.preferenceID, "vscode")
        XCTAssertTrue(application.opensDirectories)
        XCTAssertFalse(application.opensAnyFile)
        XCTAssertFalse(application.isBundleOpener)
        XCTAssertEqual(application.supportedTypeIdentifiers, [])
    }

    func testCapabilityFieldsSurviveEncodingRoundTrip() throws {
        let original = ApplicationMenuOption(
            preferenceID: "vscode",
            name: "Visual Studio Code",
            path: "/Applications/Visual Studio Code.app",
            fallbackSymbol: "chevron.left.forwardslash.chevron.right",
            supportedExtensions: ["ts"],
            opensDirectories: true,
            opensAnyFile: true,
            supportedTypeIdentifiers: ["public.source-code", "public.plain-text"],
            isBundleOpener: false
        )

        let decoded = try JSONDecoder().decode(
            ApplicationMenuOption.self,
            from: JSONEncoder().encode(original)
        )

        XCTAssertTrue(decoded.opensAnyFile)
        XCTAssertEqual(
            decoded.supportedTypeIdentifiers,
            ["public.source-code", "public.plain-text"]
        )
        XCTAssertFalse(decoded.isBundleOpener)
    }
}
