import XCTest
@testable import dmenu_mac

private struct FakeScreen: ScreenDescribing, Equatable {
    let frame: NSRect
    var visibleFrame: NSRect { frame }
}

final class ScreenPickerTests: XCTestCase {
    // Primary at the origin, a second display to its right and a third above it.
    private let primary = FakeScreen(frame: NSRect(x: 0, y: 0, width: 1440, height: 900))
    private let right = FakeScreen(frame: NSRect(x: 1440, y: -200, width: 1920, height: 1080))
    private let above = FakeScreen(frame: NSRect(x: 0, y: 900, width: 1440, height: 900))
    private var screens: [FakeScreen] { [primary, right, above] }

    private func pick(_ selection: ScreenSelection, monitor: Int? = nil,
                      mouse: NSPoint = .zero, window: NSRect? = nil,
                      fallback: FakeScreen? = nil) -> FakeScreen? {
        ScreenPicker.pick(from: screens, selection: selection, monitor: monitor,
                          context: ScreenContext(mouseLocation: mouse, activeWindowFrame: window),
                          fallback: fallback)
    }

    // MARK: - Primary

    func testPrimaryPicksFirstScreen() {
        XCTAssertEqual(pick(.primary, mouse: NSPoint(x: 2000, y: 100)), primary)
    }

    // MARK: - Mouse

    func testMousePicksScreenUnderPointer() {
        XCTAssertEqual(pick(.mouse, mouse: NSPoint(x: 2000, y: 100)), right)
        XCTAssertEqual(pick(.mouse, mouse: NSPoint(x: 100, y: 1200)), above)
    }

    func testMouseOnTopEdgeCountsAsThatScreen() {
        // Cocoa reports the pointer at the very top of a display as y == maxY.
        XCTAssertEqual(pick(.mouse, mouse: NSPoint(x: 2000, y: 880)), right)
    }

    func testMouseOutsideAllScreensFallsBack() {
        XCTAssertEqual(pick(.mouse, mouse: NSPoint(x: -500, y: -500), fallback: right), right)
        XCTAssertEqual(pick(.mouse, mouse: NSPoint(x: -500, y: -500)), primary)
    }

    // MARK: - Active window

    func testActiveWindowPicksScreenContainingIt() {
        XCTAssertEqual(pick(.activeWindow, window: NSRect(x: 1600, y: 0, width: 800, height: 600)), right)
    }

    func testActiveWindowSpanningScreensPicksLargestOverlap() {
        let window = NSRect(x: 1000, y: 100, width: 1000, height: 600)
        XCTAssertEqual(pick(.activeWindow, window: window), right)
    }

    func testNoActiveWindowFallsBack() {
        XCTAssertEqual(pick(.activeWindow, fallback: above), above)
    }

    func testOffscreenActiveWindowFallsBack() {
        let window = NSRect(x: -5000, y: -5000, width: 100, height: 100)
        XCTAssertEqual(pick(.activeWindow, window: window, fallback: above), above)
    }

    // MARK: - Monitor override

    func testMonitorIndexOverridesSelection() {
        XCTAssertEqual(pick(.primary, monitor: 2), above)
        XCTAssertEqual(pick(.mouse, monitor: 0, mouse: NSPoint(x: 2000, y: 100)), primary)
    }

    func testOutOfRangeMonitorFallsBackToSelection() {
        XCTAssertEqual(pick(.mouse, monitor: 3, mouse: NSPoint(x: 2000, y: 100)), right)
        XCTAssertEqual(pick(.mouse, monitor: -1, mouse: NSPoint(x: 2000, y: 100)), right)
    }

    func testNoScreensPicksNothing() {
        let picked = ScreenPicker.pick(from: [FakeScreen](), selection: .primary,
                                       context: ScreenContext(mouseLocation: .zero))
        XCTAssertNil(picked)
    }
}
