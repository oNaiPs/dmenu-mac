import XCTest
@testable import dmenu_mac

final class ResultsViewTests: XCTestCase {
    var view: ResultsView!

    override func setUp() {
        super.setUp()
        view = ResultsView(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
    }

    override func tearDown() {
        view = nil
        super.tearDown()
    }

    private func items(_ names: String...) -> [ListItem] {
        names.map { ListItem(name: $0, data: nil) }
    }

    // MARK: - list

    func testInitiallyEmptyWithNoSelection() {
        XCTAssertTrue(view.list.isEmpty)
        XCTAssertEqual(view.selectedIndex, 0)
        XCTAssertNil(view.selectedItem())
    }

    func testSettingListResetsSelectionToFirstItem() {
        view.list = items("a", "b", "c")
        view.selectedIndex = 2

        view.list = items("x", "y")

        XCTAssertEqual(view.selectedIndex, 0)
        XCTAssertEqual(view.selectedItem()?.name, "x")
    }

    func testSettingListMarksViewForDisplay() {
        view.needsDisplay = false
        view.list = items("a")
        XCTAssertTrue(view.needsDisplay)
    }

    // MARK: - selectedIndex

    func testSelectedIndexWithinBoundsUpdatesSelection() {
        view.list = items("a", "b", "c")
        view.selectedIndex = 1
        XCTAssertEqual(view.selectedIndex, 1)
        XCTAssertEqual(view.selectedItem()?.name, "b")
    }

    func testNegativeSelectedIndexIsIgnored() {
        view.list = items("a", "b")
        view.selectedIndex = 1
        view.selectedIndex = -1
        XCTAssertEqual(view.selectedIndex, 1)
    }

    func testSelectedIndexPastEndIsIgnored() {
        view.list = items("a", "b")
        view.selectedIndex = 2
        XCTAssertEqual(view.selectedIndex, 0)
    }

    // MARK: - clear

    func testClearRemovesAllItems() {
        view.list = items("a", "b")
        view.selectedIndex = 1

        view.clear()

        XCTAssertTrue(view.list.isEmpty)
        XCTAssertNil(view.selectedItem())
    }

    // MARK: - Drawing

    func testDrawComputesSelectedRectForSelectedItem() {
        view.list = items("first", "second")
        drawOffscreen()
        let firstRect = view.selectedRect

        view.selectedIndex = 1
        drawOffscreen()

        XCTAssertEqual(firstRect.minX, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(firstRect.width, 0)
        XCTAssertGreaterThan(view.selectedRect.minX, firstRect.maxX,
                             "Second item should be drawn to the right of the first")
    }

    func testDrawWithDirtyWidthResizesToContent() {
        let scrollView = NSScrollView(frame: view.frame)
        view.setValue(scrollView, forKey: "scrollView")
        view.list = items("a")
        let initialWidth = view.frame.width

        view.updateWidth()
        XCTAssertTrue(view.dirtyWidth)
        drawOffscreen()

        XCTAssertFalse(view.dirtyWidth)
        XCTAssertLessThan(view.frame.width, initialWidth)
        XCTAssertGreaterThan(view.frame.width, 0)
    }

    func testDrawWithEmptyListDoesNotCrash() {
        drawOffscreen()
        XCTAssertGreaterThan(view.selectedRect.width, 0, "Placeholder \"No results\" is drawn selected")
    }

    private func drawOffscreen() {
        let image = NSImage(size: view.bounds.size)
        image.lockFocus()
        view.draw(view.bounds)
        image.unlockFocus()
    }
}
