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

    func testProviderFactorySelectsAppProviderWhenStdinEmpty() {
        let factory = ProviderFactory()
        let provider = factory.createProvider(stdinContent: "")

        XCTAssertTrue(provider is AppListProvider, "Should create AppListProvider when stdin is empty")
    }
}
