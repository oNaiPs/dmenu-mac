import XCTest
@testable import dmenu_mac

final class AliasSearchServiceTests: XCTestCase {
    private var provider: MockListProvider!
    private var settings: AliasSettings!
    private var service: AliasSearchService!

    private var aliases: [Alias] {
        get { settings.aliases }
        set { settings.aliases = newValue }
    }

    override func setUp() {
        super.setUp()
        provider = MockListProvider(items: [
            ListItem(name: "Firefox", data: "firefox"),
            ListItem(name: "Ghostty", data: "ghostty"),
            ListItem(name: "Terminal", data: "terminal"),
            ListItem(name: "Safari", data: "safari"),
            ListItem(name: "FaceTime", data: "facetime")
        ])
        settings = .inMemory()
        service = AliasSearchService(provider: provider, settings: settings)
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

    // MARK: - Target identity

    func testSameNamedItemsResolveByPath() {
        let first = URL(fileURLWithPath: "/Applications/Foo.app")
        let second = URL(fileURLWithPath: "/Users/me/Applications/Foo.app")
        provider.mockItems = [ListItem(name: "Foo", data: first), ListItem(name: "Foo", data: second)]

        aliases = [Alias(keyword: "foo2", item: provider.mockItems[1])]

        let results = service.search(query: "foo2")
        // The other Foo still shows as a regular fuzzy match, once, after the alias target.
        XCTAssertEqual(results.map { $0.data as? URL }, [second, first])
    }

    func testIdentityUsesPathCommandOrName() {
        let url = URL(fileURLWithPath: "/Applications/Firefox.app")
        XCTAssertEqual(ListItem(name: "Firefox", data: url).aliasIdentity, "/Applications/Firefox.app")
        XCTAssertEqual(ListItem(name: "nvim", data: Command(commandLine: "nvim")).aliasIdentity, "cmd:nvim")
        XCTAssertEqual(ListItem(name: "Other", data: nil).aliasIdentity, "name:Other")
    }

    func testIdentitySeesThroughCompositeProvider() throws {
        let url = URL(fileURLWithPath: "/Applications/Firefox.app")
        let apps = MockListProvider(items: [ListItem(name: "Firefox", data: url)])
        let commands = MockListProvider(items: [ListItem(name: "nvim", data: Command(commandLine: "nvim"))])
        let composite = CompositeListProvider(providers: [apps, commands])

        XCTAssertEqual(composite.get().map { $0.aliasIdentity }, ["/Applications/Firefox.app", "cmd:nvim"])

        aliases = [Alias(keyword: "ff", target: "Firefox", targetID: "/Applications/Firefox.app")]
        let service = AliasSearchService(provider: composite, settings: settings)
        let hit = try XCTUnwrap(service.search(query: "ff").first)
        composite.doAction(item: hit)
        XCTAssertEqual(apps.lastActionedItem?.data as? URL, url)
    }

    func testNameOnlyAliasFromOlderVersionStillWorks() throws {
        let json = "[{\"id\":\"\(UUID().uuidString)\",\"keyword\":\"ff\",\"target\":\"Firefox\"}]"
        let decoded = try JSONDecoder().decode([Alias].self, from: Data(json.utf8))
        XCTAssertNil(decoded.first?.targetID)

        aliases = decoded
        XCTAssertEqual(names("ff").first, "Firefox")
    }

    // MARK: - Storage

    func testSharedStoreIsEmptyInMemoryUnderTests() {
        XCTAssertTrue(AliasSettings.shared.aliases.isEmpty)
    }

    func testAliasesPersistInDefaults() {
        let suite = "AliasSearchServiceTests"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let alias = Alias(keyword: "ff", target: "Firefox", targetID: "/Applications/Firefox.app")

        AliasSettings(defaults: defaults).aliases = [alias]

        XCTAssertEqual(AliasSettings(defaults: defaults).aliases, [alias])
    }
}
