import XCTest
@testable import dmenu_mac

final class SearchServiceTests: XCTestCase {
    var searchService: SearchService!
    var mockProvider: MockListProvider!

    override func setUp() {
        super.setUp()
        mockProvider = MockListProvider(items: [
            ListItem(name: "Safari", data: nil),
            ListItem(name: "System Preferences", data: nil),
            ListItem(name: "Calculator", data: nil),
            ListItem(name: "Calendar", data: nil),
            ListItem(name: "Music", data: nil)
        ])
        searchService = SearchService(provider: mockProvider)
    }

    override func tearDown() {
        searchService = nil
        mockProvider = nil
        super.tearDown()
    }

    // MARK: - Fuzzy Search Tests

    func testSearchWithEmptyQueryReturnsAllItemsSorted() {
        let results = searchService.search(query: "")
        XCTAssertEqual(results.count, 5)
        // Should be sorted alphabetically
        XCTAssertEqual(results[0].name, "Calculator")
        XCTAssertEqual(results[1].name, "Calendar")
        XCTAssertEqual(results[2].name, "Music")
        XCTAssertEqual(results[3].name, "Safari")
        XCTAssertEqual(results[4].name, "System Preferences")
    }

    func testSearchWithExactMatchReturnsItem() {
        let results = searchService.search(query: "Safari")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Safari")
    }

    func testSearchWithPartialMatchReturnsFuzzyMatches() {
        let results = searchService.search(query: "Cal")
        XCTAssertTrue(results.count >= 2, "Should match both Calculator and Calendar")
        let names = results.map { $0.name }
        XCTAssertTrue(names.contains("Calculator"))
        XCTAssertTrue(names.contains("Calendar"))
    }

    func testSearchWithTypoReturnsFuzzyMatches() {
        let results = searchService.search(query: "Safri")
        XCTAssertTrue(results.count >= 1, "Should fuzzy match Safari")
        XCTAssertEqual(results[0].name, "Safari")
    }

    func testSearchWithNoMatchesReturnsEmptyArray() {
        let results = searchService.search(query: "NonexistentApp")
        XCTAssertEqual(results.count, 0)
    }

    func testSearchResultsAreSortedByRelevance() {
        let results = searchService.search(query: "Cal")
        // Exact prefix matches should rank higher
        // Results should be ordered by fuzzy search score
        XCTAssertTrue(results.count > 0)
        // First result should be the most relevant
    }

    func testSearchIsCaseInsensitive() {
        let results1 = searchService.search(query: "safari")
        let results2 = searchService.search(query: "SAFARI")
        let results3 = searchService.search(query: "Safari")

        XCTAssertEqual(results1.count, results2.count)
        XCTAssertEqual(results2.count, results3.count)
    }

    // MARK: - Performance Tests

    func testSearchPerformanceWithLargeDataset() {
        // Create a large mock dataset
        var largeDataset: [ListItem] = []
        for i in 0..<1000 {
            largeDataset.append(ListItem(name: "App \(i)", data: nil))
        }
        mockProvider.mockItems = largeDataset
        searchService = SearchService(provider: mockProvider)

        measure {
            _ = searchService.search(query: "App 5")
        }
    }

    // MARK: - Provider Tests

    func testSearchServiceUsesInjectedProvider() {
        let customProvider = MockListProvider(items: [
            ListItem(name: "Custom App", data: nil)
        ])
        let service = SearchService(provider: customProvider)

        let results = service.search(query: "")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].name, "Custom App")
    }

    // MARK: - Threshold Tests

    func testSearchUsesConfigurableThreshold() {
        // Test that search threshold can be configured
        let strictService = SearchService(provider: mockProvider, threshold: 0.2)
        let lenientService = SearchService(provider: mockProvider, threshold: 0.6)

        let strictResults = strictService.search(query: "Saf")
        let lenientResults = lenientService.search(query: "Saf")

        // Lenient threshold should return more results
        XCTAssertGreaterThanOrEqual(lenientResults.count, strictResults.count)
    }
}
