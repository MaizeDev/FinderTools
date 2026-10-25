import XCTest
@testable import FinderTools

final class ActionValidatorTests: XCTestCase {
    private let desktop = URL(fileURLWithPath: "/Users/test/Desktop", isDirectory: true)
    private let downloads = URL(fileURLWithPath: "/Users/test/Downloads", isDirectory: true)
    private let textEditPath = "/System/Applications/TextEdit.app"

    private var validator: ActionValidator {
        ActionValidator(
            enabledApplicationPaths: [textEditPath],
            authorizedFolderPaths: [desktop.path]
        )
    }

    // MARK: - URL 解析

    func testParsesCreateCommand() throws {
        let url = try XCTUnwrap(URL(
            string: "findertools://create?directory=/Users/test/Desktop&type=txt"
        ))
        let command = try FinderCommand(url: url)

        guard case .create(let directory, let fileExtension) = command.action else {
            return XCTFail("应当解析成 create 命令")
        }
        XCTAssertEqual(directory.path, desktop.path)
        XCTAssertEqual(fileExtension, "txt")
    }

    func testParsesOpenCommand() throws {
        let url = try XCTUnwrap(URL(
            string: "findertools://open?application=\(textEditPath)&item=/Users/test/Desktop/a.txt"
        ))
        let command = try FinderCommand(url: url)

        guard case .open(let application, let items) = command.action else {
            return XCTFail("应当解析成 open 命令")
        }
        XCTAssertEqual(application.path, textEditPath)
        XCTAssertEqual(items.map(\.path), ["/Users/test/Desktop/a.txt"])
    }

    func testRejectsMissingOrUnknownParameters() throws {
        let invalidURLs = [
            "findertools://create?directory=/Users/test/Desktop",          // 缺 type
            "findertools://create?type=txt",                                // 缺 directory
            "findertools://terminal",                                       // 缺 directory
            "findertools://open?application=\(textEditPath)",               // 缺 item
            "findertools://open?item=/Users/test/Desktop/a.txt",            // 缺 application
            "findertools://choose",                                         // 缺 item
            "findertools://unknown?item=/tmp/a",                            // 未知 action
            "other://create?directory=/Users/test/Desktop&type=txt"         // 非 findertools scheme
        ]

        for rawURL in invalidURLs {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertThrowsError(try FinderCommand(url: url), "应当拒绝 \(rawURL)") { error in
                XCTAssertEqual(error as? ActionValidationError, .invalidCommand)
            }
        }
    }

    // MARK: - 参数校验（与授权无关）

    func testCreateRejectsUnsupportedFileType() {
        let command = FinderCommand(action: .create(directory: desktop, fileExtension: "exe"))
        XCTAssertThrowsError(try validator.validateParameters(command)) { error in
            XCTAssertEqual(error as? ActionValidationError, .unsupportedFileType)
        }
    }

    func testOpenRejectsApplicationOutsideEnabledList() {
        // Calculator 存在且以 .app 结尾，但不在“已启用应用”名单里。
        let command = FinderCommand(action: .open(
            application: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            items: [desktop.appendingPathComponent("a.txt")]
        ))
        XCTAssertThrowsError(try validator.validateParameters(command)) { error in
            XCTAssertEqual(error as? ActionValidationError, .applicationNotAllowed)
        }
    }

    func testOpenRejectsNonApplicationPath() {
        let command = FinderCommand(action: .open(
            application: desktop.appendingPathComponent("a.txt"),
            items: [desktop.appendingPathComponent("b.txt")]
        ))
        XCTAssertThrowsError(try validator.validateParameters(command)) { error in
            XCTAssertEqual(error as? ActionValidationError, .applicationNotAllowed)
        }
    }

    func testOpenRejectsMissingApplication() {
        let command = FinderCommand(action: .open(
            application: URL(fileURLWithPath: "/Applications/DoesNotExist.app"),
            items: [desktop.appendingPathComponent("a.txt")]
        ))
        XCTAssertThrowsError(try validator.validateParameters(command)) { error in
            XCTAssertEqual(error as? ActionValidationError, .applicationNotAllowed)
        }
    }

    func testOpenAcceptsEnabledApplication() {
        let command = FinderCommand(action: .open(
            application: URL(fileURLWithPath: textEditPath),
            items: [desktop.appendingPathComponent("a.txt")]
        ))
        XCTAssertNoThrow(try validator.validateParameters(command))
    }

    func testRejectsTooManyItems() {
        let items = (0..<(ActionValidator.maximumItemCount + 1)).map {
            desktop.appendingPathComponent("file\($0).txt")
        }
        let command = FinderCommand(action: .open(
            application: URL(fileURLWithPath: textEditPath),
            items: items
        ))
        XCTAssertThrowsError(try validator.validateParameters(command)) { error in
            XCTAssertEqual(
                error as? ActionValidationError,
                .tooManyItems(limit: ActionValidator.maximumItemCount)
            )
        }
    }

    // MARK: - 目标必须在授权文件夹内

    func testAcceptsTargetsInsideAuthorizedFolder() {
        let command = FinderCommand(action: .terminal(directory: desktop))
        XCTAssertNoThrow(try validator.validateAuthorizedTargets(command))
    }

    func testRejectsTargetsOutsideAuthorizedFolder() {
        let command = FinderCommand(action: .choose(items: [downloads.appendingPathComponent("a.txt")]))
        XCTAssertThrowsError(try validator.validateAuthorizedTargets(command)) { error in
            XCTAssertEqual(error as? ActionValidationError, .targetOutsideAuthorizedFolders)
        }
    }

    func testRejectsFolderNamePrefixSibling() {
        // /Users/test/Desktop-old 只是名字前缀相同，不是 /Users/test/Desktop 的子路径。
        let sibling = URL(fileURLWithPath: "/Users/test/Desktop-old", isDirectory: true)
        let command = FinderCommand(action: .terminal(directory: sibling))
        XCTAssertThrowsError(try validator.validateAuthorizedTargets(command)) { error in
            XCTAssertEqual(error as? ActionValidationError, .targetOutsideAuthorizedFolders)
        }
    }

    // MARK: - create 限流

    func testCreateRateLimiterAllowsFiveCreatesPerSecondPerDirectory() {
        var rateLimiter = CreateRateLimiter()
        let now = Date()

        for _ in 0..<CreateRateLimiter.maximumCreates {
            XCTAssertTrue(rateLimiter.allowCreate(in: desktop, now: now))
        }
        XCTAssertFalse(rateLimiter.allowCreate(in: desktop, now: now))

        // 另一个目录有自己的额度。
        XCTAssertTrue(rateLimiter.allowCreate(in: downloads, now: now))

        // 时间窗口过去后恢复。
        let later = now.addingTimeInterval(CreateRateLimiter.window + 0.1)
        XCTAssertTrue(rateLimiter.allowCreate(in: desktop, now: later))
    }
}
