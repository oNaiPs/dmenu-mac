import XCTest
@testable import dmenu_mac

final class SearchWindowTests: XCTestCase {

    func testWindowIsAboveDock() {
        let window = SearchWindow()
        window.awakeFromNib()

        XCTAssertGreaterThan(window.level.rawValue, NSWindow.Level.dock.rawValue)
    }

    func testWindowIsBelowMenuBar() {
        let window = SearchWindow()
        window.awakeFromNib()

        XCTAssertLessThan(window.level.rawValue, NSWindow.Level.mainMenu.rawValue)
    }

    // MARK: - Focus

    func testWindowDoesNotActivateApp() {
        let window = SearchWindow()
        window.awakeFromNib()

        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(window.canBecomeKey)
        XCTAssertFalse(window.canBecomeMain)
        XCTAssertFalse(window.hidesOnDeactivate)
    }

    func testWindowHidesWhenResigningKey() {
        let window = SearchWindow()
        window.awakeFromNib()
        window.orderFront(nil)
        XCTAssertTrue(window.isVisible)

        window.resignKey()

        XCTAssertFalse(window.isVisible)
    }

    // MARK: - Position

    // Offset origin, like a secondary display.
    private let screenFrame = NSRect(x: 1440, y: -200, width: 1920, height: 1080)

    func testTopFrameIsPinnedToTopEdge() {
        let frame = SearchWindow.frame(for: .top, in: screenFrame, height: 30)
        XCTAssertEqual(frame, NSRect(x: 1440, y: 850, width: 1920, height: 30))
    }

    func testBottomFrameIsPinnedToBottomEdge() {
        let frame = SearchWindow.frame(for: .bottom, in: screenFrame, height: 30)
        XCTAssertEqual(frame, NSRect(x: 1440, y: -200, width: 1920, height: 30))
    }

    func testBarAreaKeepsFullWidthButSkipsMenuBarAndBottomDock() {
        struct Screen: ScreenDescribing {
            let frame = NSRect(x: 1440, y: -200, width: 1920, height: 1080)
            // Menu bar on top, Dock on the left and a bottom Dock inset.
            let visibleFrame = NSRect(x: 1520, y: -150, width: 1840, height: 995)
        }
        XCTAssertEqual(SearchWindow.barArea(of: Screen()), NSRect(x: 1440, y: -150, width: 1920, height: 995))
    }
}
