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
}
