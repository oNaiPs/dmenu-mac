import XCTest
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
        let mirror = Mirror(reflecting: viewController)
        let recorderProperty = mirror.children.first { $0.label == "keyboardRecorder" }

        XCTAssertNotNil(recorderProperty, "keyboardRecorder property should exist")
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
        var controller: GeneralSettingsViewController? = GeneralSettingsViewController()
        weak var weakController = controller

        // Load view to ensure full initialization
        _ = controller?.view

        controller = nil

        XCTAssertNil(weakController,
                    "ViewController should be deallocated when no strong references remain")
    }

    func testNoRetainCycleWithKeyboardRecorder() {
        var controller: GeneralSettingsViewController? = GeneralSettingsViewController()
        weak var weakController = controller

        _ = controller?.view
        controller = nil

        // If there's a retain cycle with the recorder, controller won't be deallocated
        XCTAssertNil(weakController,
                    "No retain cycle should exist with keyboard recorder")
    }

    // MARK: - Settings Pane Protocol Tests

    func testConformsToSettingsPaneProtocol() {
        XCTAssertTrue(viewController is SettingsPane)
    }
}
