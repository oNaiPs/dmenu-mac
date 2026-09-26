import XCTest
import Settings
import KeyboardShortcuts
@testable import dmenu_mac

final class GeneralSettingsViewControllerTests: XCTestCase {
    var viewController: GeneralSettingsViewController!

    override func setUp() {
        super.setUp()
        viewController = GeneralSettingsViewController()
    }

    override func tearDown() {
        viewController = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testViewControllerCanBeCreated() {
        XCTAssertNotNil(viewController)
    }

    func testViewControllerHasCorrectPaneIdentifier() {
        XCTAssertEqual(viewController.paneIdentifier, .general)
    }

    func testViewControllerHasCorrectPaneTitle() {
        XCTAssertEqual(viewController.paneTitle, "General")
    }

    func testViewControllerHasToolbarIcon() {
        XCTAssertNotNil(viewController.toolbarItemIcon)
    }

    func testViewControllerHasCorrectNibName() {
        XCTAssertEqual(viewController.nibName, "GeneralSettingsViewController")
    }

    // MARK: - View Loading Tests

    func testViewLoadsWithoutCrashing() {
        // Force view to load
        _ = viewController.view
        XCTAssertNotNil(viewController.view)
    }

    func testCustomViewIsConnectedAfterViewLoad() {
        _ = viewController.view
        // customView should be connected via IBOutlet from XIB
        XCTAssertNotNil(viewController.value(forKey: "customView"))
    }

    // MARK: - Keyboard Recorder Tests

    func testKeyboardRecorderIsCreatedAfterViewLoad() {
        _ = viewController.view

        // Access private property via reflection for testing
        let mirror = Mirror(reflecting: viewController!)
        let recorder = mirror.children.first { $0.label == "keyboardRecorder" }?.value

        XCTAssertNotNil(recorder as? KeyboardShortcuts.RecorderCocoa, "keyboardRecorder should be set")
    }

    func testKeyboardRecorderIsAddedToCustomView() {
        _ = viewController.view

        if let customView = viewController.value(forKey: "customView") as? NSView {
            XCTAssertTrue(customView.subviews.count > 0,
                         "customView should have keyboard recorder as subview")
        } else {
            XCTFail("customView should be available")
        }
    }

    // MARK: - Memory Management Tests

    func testViewControllerCanBeDeallocated() {
        weak var weakController: GeneralSettingsViewController?

        // Nib loading autoreleases the controller; drain the pool before checking.
        autoreleasepool {
            let controller = GeneralSettingsViewController()
            weakController = controller
            // Load view to ensure full initialization
            _ = controller.view
        }

        XCTAssertNil(weakController,
                    "ViewController should be deallocated when no strong references remain")
    }

    func testNoRetainCycleWithKeyboardRecorder() {
        weak var weakController: GeneralSettingsViewController?

        autoreleasepool {
            let controller = GeneralSettingsViewController()
            weakController = controller
            _ = controller.view
        }

        // If there's a retain cycle with the recorder, controller won't be deallocated
        XCTAssertNil(weakController,
                    "No retain cycle should exist with keyboard recorder")
    }

    // MARK: - Settings Pane Protocol Tests

    func testConformsToSettingsPaneProtocol() {
        XCTAssertTrue(viewController is SettingsPane)
    }
}
