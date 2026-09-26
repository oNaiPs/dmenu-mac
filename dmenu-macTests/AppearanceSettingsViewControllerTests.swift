import XCTest
import Settings
@testable import dmenu_mac

final class AppearanceSettingsViewControllerTests: XCTestCase {
    var viewController: AppearanceSettingsViewController!
    private var snapshot: AppearanceDefaultsSnapshot!

    override func setUp() {
        super.setUp()
        snapshot = AppearanceDefaultsSnapshot()
        AppearanceDefaultsSnapshot.clear()
        viewController = AppearanceSettingsViewController()
    }

    override func tearDown() {
        viewController = nil
        snapshot.restore()
        super.tearDown()
    }

    // MARK: - Pane metadata

    func testPaneMetadata() {
        XCTAssertEqual(viewController.paneIdentifier, .appearance)
        XCTAssertEqual(viewController.paneTitle, "Appearance")
        XCTAssertNotNil(viewController.toolbarItemIcon)
        XCTAssertEqual(viewController.nibName, "AppearanceSettingsViewController")
    }

    // MARK: - View loading

    func testViewLoadsAndConnectsOutlets() {
        _ = viewController.view

        XCTAssertNotNil(viewController.searchTextColorWell)
        XCTAssertNotNil(viewController.resultsTextColorWell)
        XCTAssertNotNil(viewController.selectionHighlightColorWell)
        XCTAssertNotNil(viewController.windowBackgroundColorWell)
        XCTAssertNotNil(viewController.opacitySlider)
        XCTAssertNotNil(viewController.opacityLabel)
        XCTAssertNotNil(viewController.fontNameLabel)
        XCTAssertNotNil(viewController.fontSizeLabel)
        XCTAssertNotNil(viewController.fontSizeStepper)
    }

    func testControlRangesAreConfigured() {
        _ = viewController.view

        XCTAssertEqual(viewController.opacitySlider.minValue, 0.2, accuracy: 0.0001)
        XCTAssertEqual(viewController.opacitySlider.maxValue, 1.0, accuracy: 0.0001)
        XCTAssertEqual(viewController.fontSizeStepper.minValue, 8, accuracy: 0.0001)
        XCTAssertEqual(viewController.fontSizeStepper.maxValue, 72, accuracy: 0.0001)
        XCTAssertEqual(viewController.fontSizeStepper.increment, 1, accuracy: 0.0001)
    }

    func testControlsReflectStoredSettings() {
        let manager = AppearanceManager.shared
        manager.windowOpacity = 0.75
        manager.fontSize = 18

        _ = viewController.view

        XCTAssertEqual(viewController.opacitySlider.doubleValue, 0.75, accuracy: 0.0001)
        XCTAssertEqual(viewController.opacityLabel.stringValue, "75%")
        XCTAssertEqual(viewController.fontSizeStepper.doubleValue, 18, accuracy: 0.0001)
        XCTAssertEqual(viewController.fontSizeLabel.stringValue, "18 pt")
    }

    // MARK: - Reset

    func testResetToDefaultsRestoresControlsAndNotifies() {
        let manager = AppearanceManager.shared
        manager.windowOpacity = 0.3
        manager.fontSize = 40
        _ = viewController.view

        let notified = expectation(forNotification: .appearanceSettingsChanged, object: nil)
        viewController.resetToDefaults(self)
        wait(for: [notified], timeout: 1.0)

        XCTAssertEqual(manager.windowOpacity, 0.6, accuracy: 0.0001)
        XCTAssertEqual(viewController.opacitySlider.doubleValue, 0.6, accuracy: 0.0001)
        XCTAssertEqual(viewController.opacityLabel.stringValue, "60%")
        XCTAssertEqual(viewController.fontSizeLabel.stringValue, "13 pt")
    }

    // MARK: - Memory management

    func testViewControllerCanBeDeallocated() {
        var controller: AppearanceSettingsViewController? = AppearanceSettingsViewController()
        weak var weakController = controller
        _ = controller?.view

        controller = nil

        XCTAssertNil(weakController)
    }
}
