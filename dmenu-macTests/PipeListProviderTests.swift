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

    func testInitTrimsLeadingWhitespaceAndNewlines() {
        let provider = PipeListProvider(str: "\n  one\ntwo")
        XCTAssertEqual(provider.get().map { $0.name }, ["one", "two"])
    }

    func testInitKeepsWhitespaceInsideLines() {
        let provider = PipeListProvider(str: "a b  \n  c d")
        XCTAssertEqual(provider.get().map { $0.name }, ["a b  ", "  c d"])
    }

    func testSingleLineWithoutNewline() {
        let provider = PipeListProvider(str: "only")
        XCTAssertEqual(provider.get().map { $0.name }, ["only"])
    }

    func testItemsCarryNoData() {
        let provider = PipeListProvider(str: "one\ntwo")
        XCTAssertTrue(provider.get().allSatisfy { $0.data == nil })
    }
}
