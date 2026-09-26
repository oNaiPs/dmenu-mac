import XCTest
@testable import dmenu_mac

/// Exercises keyboard handling without loading the storyboard: outlets are injected via KVC.
final class SearchViewControllerCommandTests: XCTestCase {
    var viewController: SearchViewController!
    var mockProvider: MockListProvider!
    var searchText: InputField!
    var resultsView: ResultsView!

    override func setUp() {
        super.setUp()
        mockProvider = MockListProvider(items: [
            ListItem(name: "Safari", data: nil),
            ListItem(name: "Calculator", data: nil),
            ListItem(name: "Calendar", data: nil)
        ])
        searchText = InputField()
        resultsView = ResultsView(frame: NSRect(x: 0, y: 0, width: 400, height: 30))

        viewController = SearchViewController()
        viewController.setValue(searchText, forKey: "searchText")
        viewController.setValue(resultsView, forKey: "resultsText")
        viewController.listProvider = mockProvider
        viewController.searchService = SearchService(provider: mockProvider)
        // A non-empty prompt keeps closeApp() from hiding the test host.
        viewController.promptValue = "prompt"
        viewController.clearFields()
    }

    override func tearDown() {
        viewController = nil
        mockProvider = nil
        searchText = nil
        resultsView = nil
        super.tearDown()
    }

    @discardableResult
    private func send(_ selector: Selector) -> Bool {
        viewController.control(NSTextField(), textView: NSTextView(), doCommandBy: selector)
    }

    private func type(_ text: String) {
        searchText.stringValue = text
        viewController.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    // MARK: - clearFields

    func testClearFieldsShowsPromptAndAllItemsSorted() {
        XCTAssertEqual(searchText.stringValue, "prompt")
        XCTAssertEqual(resultsView.list.map { $0.name }, ["Calculator", "Calendar", "Safari"])
    }

    func testClearFieldsWithoutSearchServiceShowsNoItems() {
        viewController.searchService = nil
        viewController.clearFields()
        XCTAssertTrue(resultsView.list.isEmpty)
    }

    // MARK: - Typing

    func testTypingFiltersResults() {
        type("Safari")
        XCTAssertEqual(resultsView.list.map { $0.name }, ["Safari"])
        XCTAssertTrue(resultsView.dirtyWidth)
    }

    func testTypingWithoutMatchesClearsResults() {
        type("zzzzzzzzzz")
        XCTAssertTrue(resultsView.list.isEmpty)
    }

    func testClearingTextRestoresFullList() {
        type("Safari")
        type("")
        XCTAssertEqual(resultsView.list.count, 3)
        XCTAssertEqual(searchText.stringValue, "prompt")
    }

    // MARK: - Navigation

    func testMoveRightAdvancesSelection() {
        XCTAssertTrue(send(#selector(NSResponder.moveRight(_:))))
        XCTAssertEqual(resultsView.selectedIndex, 1)
    }

    func testInsertTabActsLikeMoveRight() {
        XCTAssertTrue(send(#selector(NSResponder.insertTab(_:))))
        XCTAssertEqual(resultsView.selectedIndex, 1)
    }

    func testMoveRightWrapsToFirstItem() {
        resultsView.selectedIndex = 2
        send(#selector(NSResponder.moveRight(_:)))
        XCTAssertEqual(resultsView.selectedIndex, 0)
    }

    func testMoveLeftWrapsToLastItem() {
        XCTAssertTrue(send(#selector(NSResponder.moveLeft(_:))))
        XCTAssertEqual(resultsView.selectedIndex, 2)
    }

    func testInsertBacktabActsLikeMoveLeft() {
        resultsView.selectedIndex = 2
        XCTAssertTrue(send(#selector(NSResponder.insertBacktab(_:))))
        XCTAssertEqual(resultsView.selectedIndex, 1)
    }

    func testNavigationMarksWidthDirty() {
        resultsView.dirtyWidth = false
        send(#selector(NSResponder.moveRight(_:)))
        XCTAssertTrue(resultsView.dirtyWidth)
    }

    // MARK: - Enter / Escape

    func testInsertNewlinePerformsActionOnSelectedItem() {
        resultsView.selectedIndex = 1

        XCTAssertTrue(send(#selector(NSResponder.insertNewline(_:))))

        XCTAssertEqual(mockProvider.actionCallCount, 1)
        XCTAssertEqual(mockProvider.lastActionedItem?.name, "Calendar")
    }

    func testInsertNewlineResetsFieldsAfterAction() {
        type("Safari")
        send(#selector(NSResponder.insertNewline(_:)))
        XCTAssertEqual(searchText.stringValue, "prompt")
        XCTAssertEqual(resultsView.list.count, 3)
    }

    func testInsertNewlineWithNoResultsDoesNothing() {
        type("zzzzzzzzzz")
        XCTAssertTrue(send(#selector(NSResponder.insertNewline(_:))))
        XCTAssertEqual(mockProvider.actionCallCount, 0)
    }

    func testCancelOperationClearsFieldsWithoutAction() {
        type("Safari")

        XCTAssertTrue(send(#selector(NSResponder.cancelOperation(_:))))

        XCTAssertEqual(mockProvider.actionCallCount, 0)
        XCTAssertEqual(searchText.stringValue, "prompt")
        XCTAssertEqual(resultsView.list.count, 3)
    }

    func testUnhandledCommandReturnsFalse() {
        XCTAssertFalse(send(#selector(NSResponder.moveUp(_:))))
        XCTAssertFalse(send(#selector(NSResponder.deleteBackward(_:))))
    }
}
