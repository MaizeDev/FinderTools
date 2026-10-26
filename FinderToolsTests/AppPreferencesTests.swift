import XCTest
@testable import FinderTools

final class AppPreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults?

    override func setUp() {
        super.setUp()
        suiteName = "com.wheat.FinderToolsTests.preferences.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults?.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = ""
        super.tearDown()
    }

    private func preferences() -> AppPreferences {
        AppPreferences(defaults: defaults ?? .standard)
    }

    func testDefaultKeepsDockIcon() {
        XCTAssertFalse(preferences().hideDockIconAfterLastWindowClosed)
    }

    func testSettingIsPersisted() {
        preferences().hideDockIconAfterLastWindowClosed = true

        let reloaded = AppPreferences(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
        XCTAssertTrue(reloaded.hideDockIconAfterLastWindowClosed)
    }

    func testSettingCanBeTurnedOffAgain() {
        preferences().hideDockIconAfterLastWindowClosed = true
        preferences().hideDockIconAfterLastWindowClosed = false

        XCTAssertFalse(preferences().hideDockIconAfterLastWindowClosed)
    }

    // MARK: - 第 20 步：登录启动提示条

    func testLaunchAtLoginHintIsShownByDefault() {
        XCTAssertFalse(preferences().hasDismissedLaunchAtLoginHint)
    }

    func testLaunchAtLoginHintDismissalIsPersisted() {
        preferences().hasDismissedLaunchAtLoginHint = true

        let reloaded = AppPreferences(defaults: UserDefaults(suiteName: suiteName) ?? .standard)
        XCTAssertTrue(reloaded.hasDismissedLaunchAtLoginHint)
    }
}
