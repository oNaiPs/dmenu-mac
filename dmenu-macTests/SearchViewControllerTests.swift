import XCTest
@testable import dmenu_mac

final class SearchViewControllerTests: XCTestCase {
    var viewController: SearchViewController!
    var mockProvider: MockListProvider!

    // Note: These tests verify the ViewController can be properly dependency-injected
    // Full UI testing would require loading from storyboard

    override func tearDown() {
        viewController = nil
        mockProvider = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testViewControllerCanBeCreated() {
        viewController = SearchViewController()
        XCTAssertNotNil(viewController)
    }

    // MARK: - Dependency Injection Tests

    func testViewControllerAcceptsInjectedProvider() {
        viewController = SearchViewController()
        mockProvider = MockListProvider(items: [
            ListItem(name: "Test App", data: nil)
        ])

        // After refactoring, we should be able to inject the provider
        viewController.listProvider = mockProvider

        XCTAssertNotNil(viewController.listProvider)
        let items = viewController.listProvider?.get()
        XCTAssertEqual(items?.count, 1)
        XCTAssertEqual(items?[0].name, "Test App")
    }

    // MARK: - Window Position Tests

    func testWindowPositionFollowsSettingWithoutOverride() {
        viewController = SearchViewController()
        XCTAssertEqual(viewController.windowPosition, AppearanceManager.shared.windowPosition)
    }

    func testWindowPositionOverrideWins() {
        viewController = SearchViewController()
        viewController.windowPositionOverride = .bottom
        XCTAssertEqual(viewController.windowPosition, .bottom)
    }

    // MARK: - Memory Management Tests

    func testViewControllerRemovesObserverOnDeinit() {
        // This test verifies that deinit is properly implemented
        // We'll test this by ensuring the view controller can be deallocated

        var controller: SearchViewController? = SearchViewController()
        weak var weakController = controller

        controller = nil

        // Controller should be deallocated (no retain cycles)
        XCTAssertNil(weakController, "ViewController should be deallocated when no strong references remain")
    }

    // MARK: - Provider Selection Tests

    func testProviderFactorySelectsPipeProviderWhenStdinPresent() {
        let factory = ProviderFactory()
        let provider = factory.createProvider(stdinContent: "option1\noption2\n")

        XCTAssertTrue(provider is PipeListProvider, "Should create PipeListProvider when stdin has content")
    }

    func testProviderFactorySelectsAppAndCommandProvidersWhenStdinEmpty() {
        let factory = ProviderFactory()
        let provider = factory.createProvider(stdinContent: "")

        guard let composite = provider as? CompositeListProvider else {
            return XCTFail("Should create CompositeListProvider when stdin is empty")
        }
        XCTAssertEqual(composite.providers.count, 2)
        XCTAssertTrue(composite.providers[0] is AppListProvider)
        XCTAssertTrue(composite.providers[1] is CommandListProvider)
        XCTAssertTrue(composite.inputProvider is CommandListProvider, "Typed commands may need a terminal")
    }
}
