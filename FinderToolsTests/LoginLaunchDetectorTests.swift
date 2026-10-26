import AppKit
import XCTest
@testable import FinderTools

final class LoginLaunchDetectorTests: XCTestCase {
    private func openApplicationEvent(launchedAsLoginItem: Bool) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        if launchedAsLoginItem {
            event.setParam(
                NSAppleEventDescriptor(boolean: true),
                forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
            )
        }
        return event
    }

    /// 普通启动：`oapp` 事件存在，但没有 `lgit` 参数。
    func testNormalLaunchIsNotTreatedAsLoginItemLaunch() {
        XCTAssertFalse(
            LoginLaunchDetector.isLoginItemLaunch(
                currentAppleEvent: openApplicationEvent(launchedAsLoginItem: false)
            )
        )
    }

    /// 登录项启动：`oapp` 事件带 `keyAELaunchedAsLogInItem` 参数。
    func testLoginItemLaunchIsDetected() {
        XCTAssertTrue(
            LoginLaunchDetector.isLoginItemLaunch(
                currentAppleEvent: openApplicationEvent(launchedAsLoginItem: true)
            )
        )
    }

    /// 没有可用的 Apple 事件（例如非 LaunchServices 启动）时不能误判为登录启动。
    func testMissingAppleEventIsNotLoginItemLaunch() {
        XCTAssertFalse(LoginLaunchDetector.isLoginItemLaunch(currentAppleEvent: nil))
    }

    /// 其他 Apple 事件（例如打开文档）即使碰巧带 `lgit` 也不能当成登录启动。
    func testUnrelatedAppleEventIsNotLoginItemLaunch() {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEOpenDocuments),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(
            NSAppleEventDescriptor(boolean: true),
            forKeyword: AEKeyword(keyAELaunchedAsLogInItem)
        )

        XCTAssertFalse(LoginLaunchDetector.isLoginItemLaunch(currentAppleEvent: event))
    }
}
