import XCTest
@testable import FinderTools

final class SelectionMatcherTests: XCTestCase {
    private static func application(
        id: String,
        supportedExtensions: [String] = [],
        opensDirectories: Bool = false,
        opensAnyFile: Bool = false,
        supportedTypeIdentifiers: [String] = [],
        isBundleOpener: Bool = false
    ) -> ApplicationMenuOption {
        ApplicationMenuOption(
            preferenceID: id,
            name: id,
            path: "/Applications/\(id).app",
            fallbackSymbol: "app",
            supportedExtensions: supportedExtensions,
            opensDirectories: opensDirectories,
            opensAnyFile: opensAnyFile,
            supportedTypeIdentifiers: supportedTypeIdentifiers,
            isBundleOpener: isBundleOpener
        )
    }

    /// 合成目录，不依赖本机装了哪些 App。
    private let applications: [ApplicationMenuOption] = [
        application(id: "terminal", opensDirectories: true),
        application(id: "vscode", opensDirectories: true, opensAnyFile: true),
        application(id: "cursor", opensDirectories: true, opensAnyFile: true),
        application(id: "sublime", opensDirectories: true, opensAnyFile: true),
        application(id: "xcode", opensDirectories: true, opensAnyFile: true),
        application(id: "bbedit", opensAnyFile: true),
        application(id: "textedit", opensAnyFile: true),
        application(id: "shellEditor", supportedTypeIdentifiers: ["public.shell-script"]),
        application(id: "rtfdEditor", supportedTypeIdentifiers: ["com.apple.rtfd"], isBundleOpener: true),
        application(id: "word", supportedExtensions: ["docx", "txt"]),
        application(id: "iina", supportedExtensions: ["mp4"])
    ]

    private var matcher: SelectionMatcher {
        makeMatcher(applications)
    }

    private func makeMatcher(_ applications: [ApplicationMenuOption]) -> SelectionMatcher {
        var applicationsByExtension: [String: [ApplicationMenuOption]] = [:]
        for application in applications {
            for fileExtension in application.supportedExtensions {
                applicationsByExtension[fileExtension.lowercased(), default: []].append(application)
            }
        }
        return SelectionMatcher(
            allApplications: applications,
            applicationsByExtension: applicationsByExtension,
            directoryApplications: applications.filter(\.opensDirectories)
        )
    }

    private var editorIDs: Set<String> {
        ["vscode", "cursor", "sublime", "xcode", "bbedit", "textedit"]
    }

    private var directoryIDs: Set<String> {
        ["terminal", "vscode", "cursor", "sublime", "xcode"]
    }

    private func file(_ path: String, contentType: String? = nil) -> SelectionItem {
        SelectionItem(
            url: URL(fileURLWithPath: path),
            isDirectory: false,
            isPackage: false,
            contentTypeIdentifier: contentType
        )
    }

    private func directory(_ path: String) -> SelectionItem {
        SelectionItem(
            url: URL(fileURLWithPath: path, isDirectory: true),
            isDirectory: true,
            isPackage: false,
            contentTypeIdentifier: "public.folder"
        )
    }

    private func package(_ path: String, contentType: String) -> SelectionItem {
        SelectionItem(
            url: URL(fileURLWithPath: path, isDirectory: true),
            isDirectory: true,
            isPackage: true,
            contentTypeIdentifier: contentType
        )
    }

    private func identifiers(_ applications: [ApplicationMenuOption]) -> Set<String> {
        Set(applications.map(\.preferenceID))
    }

    // MARK: - 有扩展名：快照优先，快照为空才兜底（C-02）

    func testTSXHasNoExtensionSnapshotAndFallsBackToEditors() {
        let result = matcher.applications(for: [file("/tmp/Component.tsx", contentType: "com.microsoft.typescript")])
        XCTAssertEqual(identifiers(result), editorIDs)
    }

    func testGoFallsBackToEditorsWhenContentTypeUnknown() {
        let result = matcher.applications(for: [file("/tmp/main.go")])
        XCTAssertEqual(identifiers(result), editorIDs)
    }

    func testShellScriptFallsBackToDeclaredTypeAndEditors() {
        let result = matcher.applications(for: [file("/tmp/install.sh", contentType: "public.shell-script")])
        XCTAssertEqual(identifiers(result), editorIDs.union(["shellEditor"]))
    }

    func testExtensionSnapshotWinsOverFallback() {
        let result = matcher.applications(for: [file("/tmp/readme.docx", contentType: "org.openxmlformats.wordprocessingml.document")])
        XCTAssertEqual(identifiers(result), ["word"])
    }

    // MARK: - 无扩展名：只显示编辑器（C-02）

    func testMakefileShowsOnlyEditorApplications() {
        let result = matcher.applications(for: [file("/tmp/Makefile")])
        XCTAssertEqual(identifiers(result), editorIDs)
        XCTAssertFalse(identifiers(result).contains("word"))
        XCTAssertFalse(identifiers(result).contains("iina"))
    }

    func testGitIgnoreShowsOnlyEditorApplications() {
        let result = matcher.applications(for: [file("/tmp/.gitignore")])
        XCTAssertEqual(identifiers(result), editorIDs)
    }

    // MARK: - 文件夹与包（C-03）

    func testDirectoryWithDotInNameIsStillADirectory() {
        let result = matcher.applications(for: [directory("/tmp/my.project")])
        XCTAssertEqual(identifiers(result), directoryIDs)
        XCTAssertFalse(identifiers(result).contains("bbedit"))
    }

    func testApplicationBundleUsesFolderOpeners() {
        let result = matcher.applications(for: [
            package("/tmp/Calculator.app", contentType: "com.apple.application-bundle")
        ])
        XCTAssertEqual(identifiers(result), directoryIDs)
        XCTAssertFalse(identifiers(result).contains("word"))
        XCTAssertFalse(identifiers(result).contains("textedit"))
    }

    func testPackageWithDeclaredTypeShowsDeclaringApplication() {
        let result = matcher.applications(for: [
            package("/tmp/notes.rtfd", contentType: "com.apple.rtfd")
        ])
        XCTAssertEqual(identifiers(result), ["rtfdEditor"])
    }

    // MARK: - UTType.conforms(to:) 兜底

    func testFallbackMatchesDeclaredSupertype() {
        // public.json 符合 public.data；dataViewer 只声明父类型，没有 opensAnyFile。
        let dataViewer = Self.application(id: "dataViewer", supportedTypeIdentifiers: ["public.data"])
        let result = makeMatcher(applications + [dataViewer]).applications(for: [
            file("/tmp/config.custom", contentType: "public.json")
        ])
        XCTAssertEqual(identifiers(result), editorIDs.union(["dataViewer"]))
    }

    // MARK: - 多选取交集

    func testMixedFileTypesReturnIntersection() {
        let result = matcher.applications(for: [
            file("/tmp/Component.tsx", contentType: "com.microsoft.typescript"),
            file("/tmp/main.go")
        ])
        XCTAssertEqual(identifiers(result), editorIDs)
    }

    func testMixedFileAndDirectoryReturnIntersection() {
        let result = matcher.applications(for: [
            file("/tmp/Component.tsx", contentType: "com.microsoft.typescript"),
            directory("/tmp/my.project")
        ])
        XCTAssertEqual(identifiers(result), directoryIDs.intersection(editorIDs))
        XCTAssertFalse(identifiers(result).contains("terminal"))
    }

    func testMixedSelectionWithoutCommonApplicationReturnsEmpty() {
        let result = matcher.applications(for: [
            file("/tmp/readme.docx", contentType: "org.openxmlformats.wordprocessingml.document"),
            directory("/tmp/my.project")
        ])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 元数据来自文件系统（C-03）

    func testSelectionItemReadsFileSystemMetadata() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let item = SelectionItem.make(for: directoryURL)
        XCTAssertTrue(item.isDirectory)
        XCTAssertFalse(item.isPackage)
        XCTAssertEqual(item.contentTypeIdentifier, "public.folder")
    }
}
