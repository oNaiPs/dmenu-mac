import XCTest
import Settings
@testable import dmenu_mac

final class SettingsPanesTests: XCTestCase {
    private var snapshot: AppearanceDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = AppearanceDefaultsSnapshot()
        AppearanceDefaultsSnapshot.clear()
    }

    override func tearDown() {
        snapshot.restore()
        super.tearDown()
    }

    // MARK: - General

    func testGeneralPaneMetadata() {
        let pane = GeneralSettingsView.pane()

        XCTAssertEqual(pane.paneIdentifier, .general)
        XCTAssertEqual(pane.paneTitle, "General")
        XCTAssertNotNil(pane.toolbarItemIcon)
    }

    func testGeneralPaneHasUsableFittingSize() {
        let pane = GeneralSettingsView.pane()

        let size = pane.view.fittingSize
        XCTAssertEqual(size.width, SettingsLayout.paneWidth, accuracy: 0.5)
        XCTAssertGreaterThan(size.height, 40, "grouped form must report its content height, not collapse")
    }

    // MARK: - Appearance

    func testAppearancePaneMetadata() {
        let pane = AppearanceSettingsView.pane()

        XCTAssertEqual(pane.paneIdentifier, .appearance)
        XCTAssertEqual(pane.paneTitle, "Appearance")
        XCTAssertNotNil(pane.toolbarItemIcon)
    }

    func testAppearancePaneHasUsableFittingSize() {
        let pane = AppearanceSettingsView.pane()

        let size = pane.view.fittingSize
        XCTAssertEqual(size.width, SettingsLayout.paneWidth, accuracy: 0.5)
        XCTAssertGreaterThan(size.height, 200, "grouped form must report its content height, not collapse")
    }

    func testAppearancePaneIsTallerThanGeneralPane() {
        let general = GeneralSettingsView.pane().view.fittingSize
        let appearance = AppearanceSettingsView.pane().view.fittingSize

        XCTAssertGreaterThan(appearance.height, general.height)
    }

    // MARK: - Aliases

    func testAliasesPaneMetadata() {
        let pane = AliasSettingsView.pane()

        XCTAssertEqual(pane.paneIdentifier, .aliases)
        XCTAssertEqual(pane.paneTitle, "Aliases")
        XCTAssertNotNil(pane.toolbarItemIcon)
    }

    func testAliasesPaneHasUsableFittingSize() {
        let size = AliasSettingsView.pane().view.fittingSize
        XCTAssertEqual(size.width, SettingsLayout.paneWidth, accuracy: 0.5)
        XCTAssertGreaterThan(size.height, 40)
    }

    func testManyAliasesScrollInsteadOfGrowingThePane() {
        AliasSettings.shared.aliases = (0..<60).map { Alias(keyword: "a\($0)", target: "Item \($0)") }
        defer { AliasSettings.shared.aliases = [] }

        let pane = AliasSettingsView.pane()
        let window = NSWindow(contentViewController: pane)
        window.layoutIfNeeded()
        pane.view.layoutSubtreeIfNeeded()

        let list = scrollViews(in: pane.view).first { $0.frame.height == AliasSettingsView.listHeight }
        guard let list, let document = list.documentView else {
            return XCTFail("alias list should be in its own scroll view")
        }
        XCTAssertGreaterThan(document.frame.height, list.frame.height, "60 aliases overflow the list")
        XCTAssertTrue(list.hasVerticalScroller, "an overflowing list must scroll")
        XCTAssertNotEqual(list.verticalScrollElasticity, .none, "scrolling must not be disabled")
        XCTAssertLessThan(pane.view.fittingSize.height, 600, "pane fits a normal screen")
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let own = (view as? NSScrollView).map { [$0] } ?? []
        return own + view.subviews.flatMap(scrollViews)
    }

    // MARK: - Memory management

    func testPanesCanBeDeallocated() {
        weak var weakGeneral: NSViewController?
        weak var weakAppearance: NSViewController?

        autoreleasepool {
            let general = GeneralSettingsView.pane()
            let appearance = AppearanceSettingsView.pane()
            weakGeneral = general
            weakAppearance = appearance
            _ = general.view
            _ = appearance.view
        }

        XCTAssertNil(weakGeneral)
        XCTAssertNil(weakAppearance)
    }
}
