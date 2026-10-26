import XCTest
@testable import FinderTools

final class DockIconVisibilityPolicyTests: XCTestCase {
    private func policy(
        hideDockIcon: Bool,
        windows: Int
    ) -> DockIconVisibilityPolicy.ActivationPolicy {
        DockIconVisibilityPolicy.activationPolicy(
            hideDockIconAfterLastWindowClosed: hideDockIcon,
            visibleMainWindowCount: windows
        )
    }

    // MARK: - 开关 × 剩余主窗口数

    func testSwitchOffAlwaysKeepsDockIcon() {
        XCTAssertEqual(policy(hideDockIcon: false, windows: 0), .regular)
        XCTAssertEqual(policy(hideDockIcon: false, windows: 1), .regular)
        XCTAssertEqual(policy(hideDockIcon: false, windows: 5), .regular)
    }

    func testSwitchOnHidesDockIconOnlyWhenNoVisibleMainWindowRemains() {
        XCTAssertEqual(policy(hideDockIcon: true, windows: 0), .accessory)
    }

    func testSwitchOnKeepsDockIconWhileAnotherMainWindowIsVisible() {
        XCTAssertEqual(policy(hideDockIcon: true, windows: 1), .regular)
        XCTAssertEqual(policy(hideDockIcon: true, windows: 2), .regular)
    }

    // MARK: - 主窗口计数

    private func window(
        isPanel: Bool = false,
        isUtilityWindow: Bool = false,
        canBecomeMain: Bool = true,
        isVisible: Bool = true,
        isClosing: Bool = false
    ) -> DockIconVisibilityPolicy.MainWindowSnapshot {
        DockIconVisibilityPolicy.MainWindowSnapshot(
            isPanel: isPanel,
            isUtilityWindow: isUtilityWindow,
            canBecomeMain: canBecomeMain,
            isVisible: isVisible,
            isClosing: isClosing
        )
    }

    func testPanelsAreNotCountedAsMainWindows() {
        // NSOpenPanel / NSAlert 的窗口都是 NSPanel。
        XCTAssertEqual(
            DockIconVisibilityPolicy.visibleMainWindowCount(in: [
                window(),
                window(isPanel: true)
            ]),
            1
        )
        XCTAssertEqual(
            DockIconVisibilityPolicy.visibleMainWindowCount(in: [
                window(isPanel: true),
                window(isPanel: true)
            ]),
            0
        )
    }

    func testClosingWindowIsExcludedEvenThoughItIsStillVisible() {
        // willClose 时正在关闭的窗口仍然 isVisible，必须排除。
        XCTAssertEqual(
            DockIconVisibilityPolicy.visibleMainWindowCount(in: [
                window(isClosing: true),
                window()
            ]),
            1
        )
        XCTAssertEqual(
            DockIconVisibilityPolicy.visibleMainWindowCount(in: [
                window(isClosing: true)
            ]),
            0
        )
    }

    func testHiddenUtilityAndNonMainWindowsAreNotCounted() {
        XCTAssertEqual(
            DockIconVisibilityPolicy.visibleMainWindowCount(in: [
                window(isVisible: false),
                window(isUtilityWindow: true),
                window(canBecomeMain: false)
            ]),
            0
        )
    }

    func testSingleVisibleMainWindowIsCounted() {
        XCTAssertEqual(
            DockIconVisibilityPolicy.visibleMainWindowCount(in: [window()]),
            1
        )
    }
}
