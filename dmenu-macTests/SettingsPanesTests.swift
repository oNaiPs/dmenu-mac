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
