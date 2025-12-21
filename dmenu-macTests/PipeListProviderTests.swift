import XCTest
@testable import dmenu_mac

final class PipeListProviderTests: XCTestCase {
    func testInitSplitsAndTrimsTrailingNewlines() {
        let provider = PipeListProvider(str: "one\ntwo\n")
        let items = provider.get().map { $0.name }
        XCTAssertEqual(items, ["one", "two"])
    }

    func testInitPreservesEmptyLineBetweenItems() {
        let provider = PipeListProvider(str: "one\n\nthree")
        let items = provider.get().map { $0.name }
        XCTAssertEqual(items, ["one", "", "three"])
    }
}
