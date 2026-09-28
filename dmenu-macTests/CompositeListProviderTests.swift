import XCTest
@testable import dmenu_mac

final class CompositeListProviderTests: XCTestCase {
    var apps: MockListProvider!
    var commands: MockListProvider!
    var composite: CompositeListProvider!

    override func setUp() {
        super.setUp()
        apps = MockListProvider(items: [ListItem(name: "Safari", data: "safari-data")])
        commands = MockListProvider(items: [ListItem(name: "nvim", data: "nvim-data")])
        composite = CompositeListProvider(providers: [apps, commands])
    }

    func testGetMergesAllProviders() {
        XCTAssertEqual(composite.get().map { $0.name }, ["Safari", "nvim"])
    }

    func testDoActionRoutesToOwningProviderWithOriginalData() {
        let items = composite.get()

        composite.doAction(item: items[1])

        XCTAssertEqual(apps.actionCallCount, 0)
        XCTAssertEqual(commands.actionCallCount, 1)
        XCTAssertEqual(commands.lastActionedItem?.name, "nvim")
        XCTAssertEqual(commands.lastActionedItem?.data as? String, "nvim-data")
    }

    func testTypedInputGoesToFirstProviderByDefault() {
        composite.doAction(input: "mpv test.mp4")
        XCTAssertEqual(apps.inputActions, ["mpv test.mp4"])
        XCTAssertTrue(commands.inputActions.isEmpty)
    }

    func testTypedInputGoesToChosenInputProvider() {
        composite = CompositeListProvider(providers: [apps, commands], inputProvider: commands)
        composite.doAction(input: "nvim notes.md")
        XCTAssertTrue(apps.inputActions.isEmpty)
        XCTAssertEqual(commands.inputActions, ["nvim notes.md"])
    }

    func testDoActionWithForeignItemDoesNothing() {
        composite.doAction(item: ListItem(name: "Safari", data: "untagged"))
        XCTAssertEqual(apps.actionCallCount + commands.actionCallCount, 0)
    }

    func testCancelReachesAllProviders() {
        composite.cancel()
        XCTAssertEqual(apps.cancelCallCount, 1)
        XCTAssertEqual(commands.cancelCallCount, 1)
    }
}
