import XCTest
@testable import dmenu_mac

final class AliasSearchServiceTests: XCTestCase {
    private var provider: MockListProvider!
    private var aliases: [Alias] = []
    private var service: AliasSearchService!

    override func setUp() {
        super.setUp()
        provider = MockListProvider(items: [
            ListItem(name: "Firefox", data: "firefox"),
            ListItem(name: "Ghostty", data: "ghostty"),
            ListItem(name: "Terminal", data: "terminal"),
            ListItem(name: "Safari", data: "safari"),
            ListItem(name: "FaceTime", data: "facetime")
        ])
        aliases = []
        service = AliasSearchService(provider: provider, aliases: { [unowned self] in self.aliases })
    }

    private func names(_ query: String) -> [String] {
        service.search(query: query).map { $0.name }
    }

    func testWithoutAliasesBehavesLikePlainSearch() {
        let plain = SearchService(provider: provider)
        for query in ["", "ff", "ter", "Safari"] {
            XCTAssertEqual(names(query), plain.search(query: query).map { $0.name }, query)
        }
    }

    func testExactAliasPutsTargetFirst() {
        aliases = [Alias(keyword: "ff", target: "Firefox")]
        XCTAssertEqual(names("ff").first, "Firefox")
    }

    func testExactAliasIsCaseInsensitive() {
        aliases = [Alias(keyword: "ff", target: "Firefox")]
        XCTAssertEqual(names("FF").first, "Firefox")
    }

    func testExactAliasTargetIsNotDuplicated() {
        aliases = [Alias(keyword: "fire", target: "Firefox")]
        let results = names("fire")
        XCTAssertEqual(results.first, "Firefox")
        XCTAssertEqual(results.filter { $0 == "Firefox" }.count, 1)
    }

    func testExactAliasBeatsBetterFuzzyMatch() {
        aliases = [Alias(keyword: "terminal", target: "Ghostty")]
        XCTAssertEqual(names("terminal"), ["Ghostty", "Terminal"])
    }

    func testExactAliasKeepsOriginalItemData() {
        aliases = [Alias(keyword: "term", target: "Ghostty")]
        XCTAssertEqual(service.search(query: "term").first?.data as? String, "ghostty")
    }

    func testFuzzyAliasMatchAppendsTargetAfterRegularResults() {
        aliases = [Alias(keyword: "term", target: "Ghostty")]
        let results = names("ter")
        XCTAssertEqual(results.first, "Terminal")
        XCTAssertEqual(results.last, "Ghostty")
        XCTAssertEqual(results.filter { $0 == "Ghostty" }.count, 1)
    }

    func testAliasWithMissingTargetIsIgnored() {
        aliases = [Alias(keyword: "ff", target: "Netscape")]
        XCTAssertFalse(names("ff").contains("Netscape"))
    }

    func testEmptyQueryIgnoresAliases() {
        aliases = [Alias(keyword: "ff", target: "Firefox")]
        XCTAssertEqual(names(""), ["FaceTime", "Firefox", "Ghostty", "Safari", "Terminal"])
    }

    func testNoAliasMatchLeavesResultsAlone() {
        aliases = [Alias(keyword: "ff", target: "Firefox")]
        XCTAssertEqual(names("Safari"), ["Safari"])
    }

    func testPipedInputGetsPlainSearch() {
        let pipe = PipeListProvider(str: "a\nb")
        XCTAssertFalse(AliasSearchService.make(provider: pipe) is AliasSearchService)
        XCTAssertTrue(AliasSearchService.make(provider: provider) is AliasSearchService)
    }

    func testAliasesPersistInDefaults() {
        let suite = "AliasSearchServiceTests"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let alias = Alias(keyword: "ff", target: "Firefox")

        AliasSettings(defaults: defaults).aliases = [alias]

        XCTAssertEqual(AliasSettings(defaults: defaults).aliases, [alias])
    }
}
