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

    // MARK: - Layout

    func testSettingListResizesFrameToContent() {
        let initialWidth = view.frame.width

        view.list = items("a")

        XCTAssertLessThan(view.frame.width, initialWidth)
        XCTAssertGreaterThan(view.frame.width, 0)
    }

    func testFrameGrowsWithMoreItems() {
        view.list = items("first")
        let oneItemWidth = view.frame.width

        view.list = items("first", "second")

        XCTAssertGreaterThan(view.frame.width, oneItemWidth)
    }

    func testSelectedRectFollowsSelectionWithoutDrawing() {
        view.list = items("first", "second")
        let firstRect = view.selectedRect

        view.selectedIndex = 1

        XCTAssertEqual(firstRect.minX, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(firstRect.width, 0)
        XCTAssertGreaterThanOrEqual(view.selectedRect.minX, firstRect.maxX,
                                    "Second item should be laid out to the right of the first")
    }

    func testLastItemEndsAtFrameEdge() {
        view.list = items("first", "second", "third")
        view.selectedIndex = 2

        XCTAssertEqual(view.selectedRect.maxX, view.frame.width, accuracy: 0.0001)
    }

    func testInvalidateLayoutRemeasuresItems() {
        view.list = items("a")
        let widthBefore = view.frame.width

        let defaults = UserDefaults.standard
        let key = UserDefaults.AppearanceKeys.fontSize
        let saved = defaults.object(forKey: key)
        defer {
            if let saved = saved {
                defaults.set(saved, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        AppearanceManager.shared.fontSize *= 2
        view.invalidateLayout()

        XCTAssertGreaterThan(view.frame.width, widthBefore)
    }

    // MARK: - Icons

    private let appURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")

    private func withIcons(_ enabled: Bool, _ body: () -> Void) {
        let defaults = UserDefaults.standard
        let key = UserDefaults.AppearanceKeys.showIcons
        let saved = defaults.object(forKey: key)
        defer {
            if let saved = saved {
                defaults.set(saved, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        AppearanceManager.shared.showIcons = enabled
        body()
    }

    func testFileURLComesFromFileBackedItemsOnly() {
        XCTAssertEqual(ListItem(name: "Calculator", data: appURL).fileURL, appURL)
        XCTAssertNil(ListItem(name: "piped", data: nil).fileURL)
        XCTAssertNil(ListItem(name: "web", data: URL(string: "https://example.com")).fileURL)
        XCTAssertNil(ListItem(name: "nvim", data: Command(commandLine: "nvim")).fileURL)
    }

    func testFileURLSurvivesCompositeProviderTagging() {
        let provider = CompositeListProvider(providers: [
            MockListProvider(items: [ListItem(name: "Calculator", data: appURL)])
        ])
        XCTAssertEqual(provider.get().first?.fileURL, appURL)
    }

    func testStubSettingsPanesBorrowTheSystemSettingsIcon() throws {
        XCTAssertEqual(IconCache.iconSource(for: appURL), appURL)

        let stub = URL(fileURLWithPath: "/System/Library/PreferencePanes/Displays.prefPane")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: stub.path))
        XCTAssertEqual(IconCache.iconSource(for: stub).pathExtension, "app")
    }

    func testIconCacheRemoveAllDropsCachedIcons() {
        let cache = IconCache()
        _ = cache.icon(for: appURL)
        XCTAssertTrue(cache.isCached(appURL))

        cache.removeAll()

        XCTAssertFalse(cache.isCached(appURL))
    }

    func testIconsOffLeavesLayoutUnchanged() {
        withIcons(false) {
            view.list = [ListItem(name: "Calculator", data: appURL)]
            XCTAssertEqual(view.iconSide, 0)
        }
    }

    func testIconsWidenOnlyFileBackedItems() {
        var plainWidth: CGFloat = 0
        var appWidth: CGFloat = 0
        withIcons(true) {
            view.list = [ListItem(name: "Calculator", data: nil)]
            plainWidth = view.frame.width
            view.list = [ListItem(name: "Calculator", data: appURL)]
            appWidth = view.frame.width
            XCTAssertGreaterThan(view.iconSide, 0)
            XCTAssertEqual(appWidth - plainWidth, view.iconSide + view.iconSpacing, accuracy: 0.0001)
            drawOffscreen()
        }
    }

    func testIconRectSnapsToDevicePixels() {
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView?.addSubview(view)
        let scale = window.backingScaleFactor

        withIcons(true) {
            // "x" leaves the next item at a fractional offset.
            view.list = [ListItem(name: "x", data: nil), ListItem(name: "Calculator", data: appURL)]
            view.selectedIndex = 1
            let rect = view.iconRect(at: view.selectedRect.minX + view.rectFillPadding)

            for edge in [rect.minX, rect.minY, rect.maxX, rect.maxY] {
                XCTAssertEqual(edge * scale, (edge * scale).rounded(), accuracy: 0.0001)
            }
            XCTAssertEqual(rect.width, view.iconSide, accuracy: 0.0001)
        }
    }

    func testTogglingIconsTakesEffectOnInvalidateLayout() {
        withIcons(false) {
            view.list = [ListItem(name: "Calculator", data: appURL)]
            let widthWithout = view.frame.width
            AppearanceManager.shared.showIcons = true
            view.invalidateLayout()
            XCTAssertGreaterThan(view.frame.width, widthWithout)
        }
    }

    // MARK: - Culling

    func testVisibleRangeCoversAllItemsForFullBounds() {
        view.list = items("a", "b", "c")
        XCTAssertEqual(view.visibleRange(in: view.bounds), 0 ..< 3)
    }

    func testVisibleRangeOnlyIncludesItemsIntersectingRect() {
        view.list = items("first", "second", "third")
        view.selectedIndex = 1
        let secondRect = view.selectedRect

        XCTAssertEqual(view.visibleRange(in: secondRect), 1 ..< 2)
    }

    func testVisibleRangeIsEmptyPastLastItem() {
        view.list = items("a")
        let beyond = NSRect(x: view.frame.width + 100, y: 0, width: 50, height: view.bounds.height)
        XCTAssertTrue(view.visibleRange(in: beyond).isEmpty)
    }

    // MARK: - Invalidation

    func testChangingSelectionOnlyInvalidatesOldAndNewRects() {
        let recording = RecordingResultsView(frame: view.frame)
        recording.list = items("first", "second", "third")
        let firstRect = recording.selectedRect
        recording.invalidated = []

        recording.selectedIndex = 2

        XCTAssertEqual(recording.invalidated, [firstRect, recording.selectedRect])
        XCTAssertFalse(recording.invalidated.contains { $0.contains(recording.bounds) },
                       "Whole view should not be redrawn")
    }

    private final class RecordingResultsView: ResultsView {
        var invalidated: [NSRect] = []

        override func setNeedsDisplay(_ invalidRect: NSRect) {
            invalidated.append(invalidRect)
            super.setNeedsDisplay(invalidRect)
        }
    }

    // MARK: - Drawing

    func testDrawWithEmptyListDoesNotCrash() {
        drawOffscreen()
        XCTAssertGreaterThan(view.selectedRect.width, 0, "Placeholder \"No results\" is laid out selected")
    }

    func testDrawWithPartialDirtyRectDoesNotCrash() {
        view.list = items("first", "second", "third")
        let image = NSImage(size: view.bounds.size)
        image.lockFocus()
        view.draw(NSRect(x: 0, y: 0, width: 10, height: view.bounds.height))
        image.unlockFocus()
    }

    private func drawOffscreen() {
        let image = NSImage(size: view.bounds.size)
        image.lockFocus()
        view.draw(view.bounds)
        image.unlockFocus()
    }
}
