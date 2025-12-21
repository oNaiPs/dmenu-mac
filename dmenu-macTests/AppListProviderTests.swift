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

    func testListItemsAreAppBundles() {
        let items = provider.get()
        for item in items {
            guard let url = item.data as? URL else {
                XCTFail("Item data should be a URL")
                continue
            }
            XCTAssertEqual(url.pathExtension, "app", "All items should be .app bundles")
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
}
