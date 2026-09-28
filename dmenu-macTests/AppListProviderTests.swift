import XCTest
@testable import dmenu_mac

final class AppListProviderTests: XCTestCase {
    var provider: AppListProvider!

    override func setUp() {
        super.setUp()
        provider = AppListProvider()
    }

    override func tearDown() {
        provider = nil
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testProviderReturnsListItems() {
        let items = provider.get()
        XCTAssertTrue(items.count > 0, "Should find at least some applications on macOS")
    }

    func testListItemsHaveNames() {
        let items = provider.get()
        for item in items {
            XCTAssertFalse(item.name.isEmpty, "All items should have non-empty names")
        }
    }

    func testListItemsHaveURLData() {
        let items = provider.get()
        for item in items {
            XCTAssertNotNil(item.data, "All items should have data")
            XCTAssertTrue(item.data is URL, "Item data should be a URL")
        }
    }

    func testListItemsAreLaunchableBundles() {
        let items = provider.get()
        for item in items {
            guard let url = item.data as? URL else {
                XCTFail("Item data should be a URL")
                continue
            }
            XCTAssertTrue(AppListProvider.launchableExtensions.contains(url.pathExtension),
                          "All items should be .app or .prefPane bundles")
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccessToAppList() {
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        // Simulate concurrent reads (what happens during search)
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            _ = provider.get()
            expectation.fulfill()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testUpdateAppListIsThreadSafe() {
        let expectation = self.expectation(description: "Concurrent updates")
        expectation.expectedFulfillmentCount = 10

        // Simulate file watcher triggering updates while searches happen
        for _ in 0..<10 {
            DispatchQueue.global().async {
                self.provider.updateAppList()
                expectation.fulfill()
            }
        }

        // Meanwhile, read the list from main thread
        for _ in 0..<10 {
            _ = provider.get()
        }

        waitForExpectations(timeout: 5.0)
    }

    func testScansUserApplicationsDirectory() {
        let userDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").path

        XCTAssertEqual(provider.appDirDict[userDir], true)
    }

    // MARK: - Recursive Directory Scanning Tests

    func testGetAppListFindsAppsInDirectory() {
        let appsDir = URL(fileURLWithPath: "/System/Library/CoreServices/", isDirectory: true)
        let apps = provider.getAppList(appsDir, recursive: false)

        XCTAssertTrue(apps.count > 0, "Should find apps in CoreServices")
        XCTAssertTrue(apps.contains(where: { $0.lastPathComponent == "Finder.app" }),
                      "Should find Finder.app in CoreServices")
    }

    func testGetAppListNonRecursiveDoesNotScanSubdirectories() {
        let appsDir = URL(fileURLWithPath: "/System/Library/CoreServices/", isDirectory: true)
        let apps = provider.getAppList(appsDir, recursive: false)

        // All apps should be direct children
        for app in apps {
            let parentPath = app.deletingLastPathComponent().path
            XCTAssertEqual(parentPath, "/System/Library/CoreServices",
                          "Non-recursive should only return direct children")
        }
    }

    func testGetAppListRecursiveScansSubdirectories() {
        let appsDir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let apps = provider.getAppList(appsDir, recursive: true)

        // Should find apps in subdirectories (if any exist)
        XCTAssertTrue(apps.count > 0, "Should find apps recursively")
    }

    func testGetAppListFollowsSymlinkedDirectories() throws {
        // Mimics nix-darwin: /Applications/Nix Apps -> /nix/store/.../Applications
        let fileManager = FileManager.default
        let tmp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tmp) }

        let store = tmp.appendingPathComponent("store/Applications")
        let root = tmp.appendingPathComponent("root")
        try fileManager.createDirectory(at: store.appendingPathComponent("Foo.app"),
                                        withIntermediateDirectories: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(at: root.appendingPathComponent("Nix Apps"),
                                           withDestinationURL: store)
        // A loop must not recurse forever.
        try fileManager.createSymbolicLink(at: store.appendingPathComponent("loop"),
                                           withDestinationURL: root)

        let apps = provider.getAppList(root, recursive: true)

        XCTAssertEqual(apps.map { $0.lastPathComponent }, ["Foo.app"])
    }

    // MARK: - Preference Pane Tests

    func testProviderIncludesSystemPreferencePanes() {
        let panes = provider.get().filter { ($0.data as? URL)?.pathExtension == "prefPane" }
        XCTAssertTrue(panes.contains(where: { ($0.data as? URL)?.lastPathComponent == "Displays.prefPane" }),
                      "Should find Displays.prefPane in /System/Library/PreferencePanes")
    }

    func testGetAppListFindsPreferencePanes() throws {
        let fileManager = FileManager.default
        let tmp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tmp) }
        try fileManager.createDirectory(at: tmp.appendingPathComponent("Foo.prefPane"),
                                        withIntermediateDirectories: true)

        let apps = provider.getAppList(tmp, recursive: false)

        XCTAssertEqual(apps.map { $0.lastPathComponent }, ["Foo.prefPane"])
    }

    func testGetAppListSkipsDeadPreferencePanes() throws {
        let fileManager = FileManager.default
        let tmp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tmp) }
        for name in ["Passwords.prefPane", "Displays.prefPane"] {
            try fileManager.createDirectory(at: tmp.appendingPathComponent(name), withIntermediateDirectories: true)
        }

        let apps = provider.getAppList(tmp, recursive: false)

        XCTAssertEqual(apps.map { $0.lastPathComponent }, ["Displays.prefPane"])
    }

    func testProviderExcludesDeadPreferencePanes() {
        let names = provider.get().compactMap { ($0.data as? URL)?.lastPathComponent }
        XCTAssertFalse(names.contains("Passwords.prefPane"),
                       "Passwords moved to its own app; the stub pane just opens System Settings > General")
    }

    // MARK: - CoreServices Tests

    func testProviderIncludesFinderAndCoreServicesApplications() {
        let names = provider.get().compactMap { ($0.data as? URL)?.lastPathComponent }
        XCTAssertTrue(names.contains("Finder.app"))
        XCTAssertTrue(names.contains("Keychain Access.app"),
                      "Should scan /System/Library/CoreServices/Applications")
    }

    func testProviderExcludesCoreServicesAgents() {
        let names = provider.get().compactMap { ($0.data as? URL)?.lastPathComponent }
        XCTAssertFalse(names.contains("loginwindow.app"))
        XCTAssertFalse(names.contains("SystemUIServer.app"))
    }

    func testDisplayNameUsesPreferencePaneBundleName() throws {
        let fileManager = FileManager.default
        let tmp = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: tmp) }
        let pane = tmp.appendingPathComponent("UniversalAccessPref.prefPane")
        let contents = pane.appendingPathComponent("Contents")
        try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: NSDictionary = ["CFBundleName": "Accessibility", "CFBundleIdentifier": "com.example.\(UUID())"]
        try plist.write(to: contents.appendingPathComponent("Info.plist"))

        XCTAssertEqual(AppListProvider.displayName(for: pane), "Accessibility")
    }

    func testDisplayNameFallsBackToFileName() {
        let pane = URL(fileURLWithPath: "/nonexistent/Displays.prefPane")
        XCTAssertEqual(AppListProvider.displayName(for: pane), "Displays")

        let app = URL(fileURLWithPath: "/Applications/Safari.app")
        XCTAssertEqual(AppListProvider.displayName(for: app), "Safari")
    }

    // MARK: - doAction Tests

    func testDoActionWithValidURL() {
        // We can't actually test app launching in unit tests,
        // but we can verify it doesn't crash with valid data
        let testItem = ListItem(
            name: "Test App",
            data: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        )

        // This shouldn't crash
        provider.doAction(item: testItem)
    }

    func testDoActionWithInvalidDataDoesNotCrash() {
        let testItem = ListItem(name: "Invalid", data: "not a URL")

        // This should log an error but not crash
        provider.doAction(item: testItem)
    }

    func testDoActionWithNilDataDoesNotCrash() {
        let testItem = ListItem(name: "Nil Data", data: nil)

        // This should log an error but not crash
        provider.doAction(item: testItem)
    }

    // MARK: - Typed Command Tests

    func testShellProcessRunsCommandInUserLoginShell() {
        let process = AppListProvider.shellProcess(command: "mpv test.mp4",
                                                   environment: ["SHELL": "/bin/bash"])
        XCTAssertEqual(process.executableURL?.path, "/bin/bash")
        XCTAssertEqual(process.arguments, ["-l", "-c", "mpv test.mp4"])
    }

    func testShellProcessDefaultsToZsh() {
        let process = AppListProvider.shellProcess(command: "true", environment: [:])
        XCTAssertEqual(process.executableURL?.path, "/bin/zsh")
    }

    func testShellProcessStartsInHomeDirectory() {
        let process = AppListProvider.shellProcess(command: "true", environment: ["HOME": "/Users/me"])
        XCTAssertEqual(process.environment?["HOME"], "/Users/me")
        XCTAssertEqual(process.currentDirectoryURL?.path, "/Users/me")
    }

    func testShellProcessKeepsOtherEnvironment() {
        let process = AppListProvider.shellProcess(command: "true", environment: ["FOO": "bar"])
        XCTAssertEqual(process.environment?["FOO"], "bar")
    }
}
