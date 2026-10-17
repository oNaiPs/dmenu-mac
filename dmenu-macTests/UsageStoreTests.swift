import XCTest
@testable import dmenu_mac

final class UsageStoreTests: XCTestCase {
    private let suiteName = "dmenu-mac.UsageStoreTests"
    private let day: TimeInterval = 24 * 60 * 60
    var defaults: UserDefaults!
    var clock: Date!

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
        clock = Date(timeIntervalSince1970: 1_800_000_000)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        clock = nil
        super.tearDown()
    }

    private func makeStore() -> UsageStore {
        UsageStore(defaults: defaults, halfLife: 10 * day, now: { [unowned self] in self.clock })
    }

    private func app(_ name: String) -> ListItem {
        ListItem(name: name, data: URL(fileURLWithPath: "/Applications/\(name).app"))
    }

    // MARK: - Store

    func testUnusedItemScoresZero() {
        XCTAssertEqual(makeStore().score(for: app("Safari")), 0)
    }

    func testRecordAccumulates() {
        let store = makeStore()
        store.record(app("Safari"))
        store.record(app("Safari"))
        XCTAssertEqual(store.score(for: app("Safari")), 2, accuracy: 0.0001)
        XCTAssertEqual(store.score(for: app("Music")), 0)
    }

    func testScoreHalvesEveryHalfLife() {
        let store = makeStore()
        store.record(app("Safari"))
        clock = clock.addingTimeInterval(10 * day)
        XCTAssertEqual(store.score(for: app("Safari")), 0.5, accuracy: 0.0001)
    }

    func testRecentUseBeatsOldFrequentUse() {
        let store = makeStore()
        for _ in 0..<4 { store.record(app("Old")) }
        clock = clock.addingTimeInterval(40 * day)
        store.record(app("New"))
        XCTAssertGreaterThan(store.score(for: app("New")), store.score(for: app("Old")))
    }

    func testHistoryPersistsAcrossInstances() {
        makeStore().record(app("Safari"))
        XCTAssertEqual(makeStore().score(for: app("Safari")), 1, accuracy: 0.0001)
    }

    func testInstancesSharingDefaultsDoNotOverwriteEachOther() {
        let menuBar = makeStore()
        let cli = makeStore()
        menuBar.record(app("Safari"))
        cli.record(app("Music"))
        menuBar.record(app("Safari"))

        let fresh = makeStore()
        XCTAssertEqual(fresh.score(for: app("Safari")), 2, accuracy: 0.0001)
        XCTAssertEqual(fresh.score(for: app("Music")), 1, accuracy: 0.0001)
    }

    func testSearchSeesRecordsFromAnotherInstance() {
        let menuBar = makeStore()
        let provider = MockListProvider(items: [app("Calculator"), app("Calendar")])
        let service = SearchService(provider: provider, usage: menuBar)
        XCTAssertEqual(service.search(query: "").first?.name, "Calculator")

        makeStore().record(app("Calendar"))
        XCTAssertEqual(service.search(query: "").first?.name, "Calendar")
    }

    func testSharedStoreIsIsolatedUnderTests() {
        UsageStore.shared.record(app("SharedStoreProbe"))
        let real = UserDefaults.standard.dictionary(forKey: UsageStore.defaultsKey)
        XCTAssertNil(real?["file:/Applications/SharedStoreProbe.app"])
    }

    func testStaleEntriesArePrunedOnSave() {
        let store = makeStore()
        store.record(app("Old"))
        clock = clock.addingTimeInterval(100 * day)
        store.record(app("New"))
        let saved = defaults.dictionary(forKey: UsageStore.defaultsKey)
        XCTAssertEqual(saved?.keys.sorted(), ["file:/Applications/New.app"])
    }

    func testItemsWithoutIdentityAreNotRecorded() {
        let store = makeStore()
        store.record(ListItem(name: "piped choice", data: nil))
        XCTAssertEqual(store.score(for: ListItem(name: "piped choice", data: nil)), 0)
        XCTAssertNil(defaults.dictionary(forKey: UsageStore.defaultsKey))
    }

    func testCommandsAndCompositeItemsHaveIdentity() {
        XCTAssertEqual(ListItem(name: "nvim", data: Command(commandLine: "nvim")).usageKey, "cmd:nvim")

        let composite = CompositeListProvider(providers: [MockListProvider(items: [app("Safari")])])
        XCTAssertEqual(composite.get().first?.usageKey, "file:/Applications/Safari.app")
    }

    // MARK: - Search ranking

    func testEmptyQueryListsUsedItemsFirst() {
        let store = makeStore()
        store.record(app("Music"))
        store.record(app("Safari"))
        store.record(app("Safari"))
        let provider = MockListProvider(items: [app("Calculator"), app("Music"), app("Safari"), app("Calendar")])
        let service = SearchService(provider: provider, usage: store)

        XCTAssertEqual(service.search(query: "").map { $0.name }, ["Safari", "Music", "Calculator", "Calendar"])
    }

    func testUsageBreaksTiesBetweenSimilarMatches() {
        let provider = MockListProvider(items: [app("Calculator"), app("Calendar")])
        let store = makeStore()
        let service = SearchService(provider: provider, usage: store)
        XCTAssertEqual(service.search(query: "Cal").first?.name, "Calculator")

        service.recordSelection(app("Calendar"))
        XCTAssertEqual(service.search(query: "Cal").first?.name, "Calendar")
    }

    func testUsageDoesNotOverrideAMuchBetterMatch() {
        let provider = MockListProvider(items: [app("Safari"), app("Stocks")])
        let store = makeStore()
        for _ in 0..<50 { store.record(app("Stocks")) }
        let service = SearchService(provider: provider, usage: store)

        XCTAssertEqual(service.search(query: "Safari").first?.name, "Safari")
    }

    func testUsageBoostIsCapped() {
        XCTAssertEqual(SearchService.usageBoost(0), 0)
        XCTAssertGreaterThan(SearchService.usageBoost(3), SearchService.usageBoost(1))
        XCTAssertEqual(SearchService.usageBoost(1_000_000), SearchService.maxUsageBoost)
    }

    func testSubmitRecordsSelectedItem() {
        let provider = MockListProvider(items: [app("Safari"), app("Calculator")])
        let store = makeStore()
        let resultsView = ResultsView(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
        let controller = SearchViewController()
        controller.setValue(InputField(), forKey: "searchText")
        controller.setValue(resultsView, forKey: "resultsText")
        controller.listProvider = provider
        controller.searchService = SearchService(provider: provider, usage: store)
        controller.promptValue = "prompt"
        controller.clearFields()

        resultsView.selectedIndex = resultsView.list.firstIndex { $0.name == "Safari" } ?? 0
        controller.submit(preferTypedInput: false)

        XCTAssertEqual(store.score(for: app("Safari")), 1, accuracy: 0.0001)
        XCTAssertEqual(store.score(for: app("Calculator")), 0)
    }
}
