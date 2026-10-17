import XCTest
import Settings
@testable import dmenu_mac

final class SearchShortcutsTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!
    var settings: SearchShortcutSettings!

    override func setUp() {
        super.setUp()
        suiteName = "SearchShortcutsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = SearchShortcutSettings(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        settings = nil
        defaults = nil
        super.tearDown()
    }

    private var google: SearchShortcut {
        SearchShortcut.defaults.first { $0.keyword == "g" }!
    }

    // MARK: - Parsing

    func testParseSplitsKeywordAndQuery() {
        let parsed = SearchShortcut.parse("g swift actors")
        XCTAssertEqual(parsed?.keyword, "g")
        XCTAssertEqual(parsed?.query, "swift actors")
    }

    func testParseTrimsSurroundingSpaces() {
        let parsed = SearchShortcut.parse("  gh   dmenu-mac  ")
        XCTAssertEqual(parsed?.keyword, "gh")
        XCTAssertEqual(parsed?.query, "dmenu-mac")
    }

    func testParseNeedsAQuery() {
        XCTAssertNil(SearchShortcut.parse("g"))
        XCTAssertNil(SearchShortcut.parse("g "))
        XCTAssertNil(SearchShortcut.parse("g    "))
        XCTAssertNil(SearchShortcut.parse(""))
        XCTAssertNil(SearchShortcut.parse("   "))
    }

    func testKeywordValidation() {
        XCTAssertTrue(SearchShortcut.isValidKeyword("ddg"))
        XCTAssertFalse(SearchShortcut.isValidKeyword(""))
        XCTAssertFalse(SearchShortcut.isValidKeyword("d g"))
    }

    // MARK: - Expansion

    func testPercentEncodingEscapesReservedCharacters() {
        XCTAssertEqual(SearchShortcut.percentEncoded("swift actors"), "swift%20actors")
        XCTAssertEqual(SearchShortcut.percentEncoded("a&b=c#d+e?f/g"), "a%26b%3Dc%23d%2Be%3Ff%2Fg")
        XCTAssertEqual(SearchShortcut.percentEncoded("café"), "caf%C3%A9")
        XCTAssertEqual(SearchShortcut.percentEncoded("a-b_c.d~e"), "a-b_c.d~e")
    }

    func testURLTemplateExpansion() {
        let expanded = google.expanded(with: "swift & actors")
        XCTAssertEqual(expanded, "https://www.google.com/search?q=swift%20%26%20actors")
        XCTAssertNotNil(URL(string: expanded))
    }

    func testURLTemplateWithoutPlaceholderAppendsQuery() {
        let shortcut = SearchShortcut(keyword: "x", name: "X", template: "https://x.com/search?q=", kind: .url)
        XCTAssertEqual(shortcut.expanded(with: "a b"), "https://x.com/search?q=a%20b")
    }

    func testTerminalTemplateShellQuotesQuery() {
        let shortcut = SearchShortcut(keyword: "cc", name: "Claude Code", template: "claude {query}", kind: .terminal)
        XCTAssertEqual(shortcut.expanded(with: "fix it"), "claude 'fix it'")
        XCTAssertEqual(shortcut.expanded(with: "it's $(rm -rf ~) `x`"), "claude 'it'\\''s $(rm -rf ~) `x`'")
    }

    func testTerminalTemplateWithoutPlaceholderAppendsQuotedQuery() {
        let shortcut = SearchShortcut(keyword: "cx", name: "Codex", template: "codex", kind: .terminal)
        XCTAssertEqual(shortcut.expanded(with: "hi there"), "codex 'hi there'")
    }

    func testTitles() {
        XCTAssertEqual(google.title(for: "swift actors"), "Search Google for 'swift actors'")
        let codex = SearchShortcut(keyword: "cx", name: "Codex", template: "codex {query}", kind: .terminal)
        XCTAssertEqual(codex.title(for: "hi"), "Run Codex with 'hi'")
    }

    // MARK: - Defaults and persistence

    func testDefaultKeywords() {
        let keywords = settings.shortcuts.map(\.keyword)
        for keyword in ["g", "ddg", "ghs", "yt", "w", "c", "gpt", "chatgpt", "p", "cc", "cx"] {
            XCTAssertTrue(keywords.contains(keyword), "missing default \(keyword)")
        }
        XCTAssertEqual(Set(keywords).count, keywords.count, "default keywords are unique")
        XCTAssertFalse(keywords.contains("gh"), "gh is the GitHub CLI")
        XCTAssertFalse(keywords.contains("claude"), "claude is the Claude Code CLI")
        for shortcut in settings.shortcuts {
            XCTAssertTrue(shortcut.template.contains(SearchShortcut.placeholder))
            if shortcut.kind == .url {
                XCTAssertNotNil(URL(string: shortcut.expanded(with: "a b")), shortcut.keyword)
            }
        }
    }

    func testShortcutsRoundTripAndRestoreDefaults() {
        let custom = [SearchShortcut(keyword: "mdn", name: "MDN",
                                     template: "https://developer.mozilla.org/search?q={query}", kind: .url)]
        settings.shortcuts = custom
        XCTAssertEqual(SearchShortcutSettings(defaults: defaults).shortcuts, custom)

        settings.restoreDefaults()
        XCTAssertEqual(settings.shortcuts, SearchShortcut.defaults)
    }

    func testEmptyListIsKept() {
        settings.shortcuts = []
        XCTAssertEqual(settings.shortcuts, [])
    }

    func testInvalidEntriesAreSkippedNotTheWholeList() {
        let json = """
            [{"keyword": "mdn", "name": "MDN", "template": "https://mdn.io/{query}", "kind": "url"},
             {"keyword": "x", "name": "X", "template": "x {query}", "kind": "spaceship"},
             {"keyword": "y"}]
            """
        defaults.set(Data(json.utf8), forKey: UserDefaults.SearchShortcutKeys.shortcuts)
        XCTAssertEqual(settings.shortcuts.map(\.keyword), ["mdn"])
        XCTAssertNotNil(defaults.data(forKey: UserDefaults.SearchShortcutKeys.shortcuts),
                        "reading must not write back over the stored list")
    }

    func testCorruptDataFallsBackToDefaults() {
        defaults.set(Data("nope".utf8), forKey: UserDefaults.SearchShortcutKeys.shortcuts)
        XCTAssertEqual(settings.shortcuts, SearchShortcut.defaults)
    }

    func testMatchesAreCaseInsensitive() {
        let matches = settings.matches(for: "G swift")
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.shortcut.name, "Google")
        XCTAssertEqual(matches.first?.query, "swift")
        XCTAssertTrue(settings.matches(for: "zz swift").isEmpty)
        XCTAssertTrue(settings.matches(for: "g").isEmpty)
    }

    // MARK: - Provider

    func testProviderOffersShortcutAndForwardsEverythingElse() {
        let inner = MockListProvider(items: [ListItem(name: "Safari", data: nil)])
        var opened = [URL]()
        let provider = SearchShortcutProvider(wrapping: inner, settings: settings, openURL: { opened.append($0) })

        XCTAssertEqual(provider.get().map(\.name), ["Safari"])
        XCTAssertTrue(provider.items(for: "safari").items.isEmpty)

        let items = provider.items(for: "g swift actors").items
        XCTAssertFalse(provider.items(for: "g swift actors").afterMatches)
        XCTAssertEqual(items.map(\.name), ["Search Google for 'swift actors'"])

        provider.doAction(item: items[0])
        XCTAssertEqual(opened, [URL(string: "https://www.google.com/search?q=swift%20actors")!])

        provider.doAction(item: ListItem(name: "Safari", data: nil))
        XCTAssertEqual(inner.lastActionedItem?.name, "Safari")
        provider.doAction(input: "ls")
        XCTAssertEqual(inner.inputActions, ["ls"])
        provider.cancel()
        XCTAssertEqual(inner.cancelCallCount, 1)
    }

    func testSearchServicePutsShortcutFirst() {
        let inner = MockListProvider(items: [ListItem(name: "Google Chrome", data: nil)])
        let provider = SearchShortcutProvider(wrapping: inner, settings: settings, openURL: { _ in })
        let service = SearchService(provider: provider)

        XCTAssertEqual(service.search(query: "g chrome").first?.name, "Search Google for 'chrome'")
        XCTAssertEqual(service.search(query: "chrome").map(\.name), ["Google Chrome"])
    }

    func testShortcutGoesLastWhenKeywordIsAListedCommand() {
        settings.shortcuts = [SearchShortcut(keyword: "w", name: "Wikipedia",
                                             template: "https://w.org/?q={query}", kind: .url)]
        let inner = MockListProvider(items: [ListItem(name: "w", data: nil)])
        let provider = SearchShortcutProvider(wrapping: inner, settings: settings,
                                              isCommand: { $0 == "w" }, openURL: { _ in })
        let service = SearchService(provider: provider)

        XCTAssertEqual(service.search(query: "w swift").last?.name, "Search Wikipedia for 'swift'")
        XCTAssertTrue(provider.items(for: "w swift").afterMatches)
    }

    // MARK: - Settings

    func testModelEditsAreSaved() {
        let model = SearchShortcutsSettingsModel(settings: settings)
        let mdn = SearchShortcut(keyword: "mdn", name: "MDN",
                                 template: "https://developer.mozilla.org/search?q={query}", kind: .url)
        model.save(mdn, at: nil)
        XCTAssertEqual(settings.shortcuts.last, mdn)

        var renamed = mdn
        renamed.name = "Mozilla"
        model.save(renamed, at: model.shortcuts.count - 1)
        XCTAssertEqual(settings.shortcuts.last?.name, "Mozilla")
        XCTAssertEqual(settings.shortcuts.count, SearchShortcut.defaults.count + 1)

        model.delete(at: 0)
        XCTAssertFalse(settings.shortcuts.contains { $0.keyword == "g" })

        model.restoreDefaults()
        XCTAssertEqual(model.shortcuts, SearchShortcut.defaults)
        XCTAssertEqual(settings.shortcuts, SearchShortcut.defaults)
    }

    func testShortcutsPane() {
        let pane = SearchShortcutsSettingsView.pane(settings: settings)
        XCTAssertEqual(pane.paneIdentifier, .shortcuts)
        XCTAssertEqual(pane.paneTitle, "Shortcuts")
        XCTAssertNotNil(pane.toolbarItemIcon)
        let size = pane.view.fittingSize
        XCTAssertEqual(size.width, SettingsLayout.paneWidth, accuracy: 0.5)
        XCTAssertGreaterThan(size.height, 200)
    }

    func testShortcutListScrollsWhenItOverflows() {
        let pane = SearchShortcutsSettingsView.pane(settings: settings)
        let window = NSWindow(contentViewController: pane)
        window.layoutIfNeeded()
        pane.view.layoutSubtreeIfNeeded()

        let list = scrollViews(in: pane.view).first { $0.frame.height == SearchShortcutsSettingsView.listHeight }
        guard let list = list, let document = list.documentView else {
            return XCTFail("shortcut list should be in its own scroll view")
        }
        XCTAssertGreaterThan(document.frame.height, list.frame.height, "the defaults overflow the list")
        XCTAssertTrue(list.hasVerticalScroller, "an overflowing list must scroll")
        XCTAssertNotEqual(list.verticalScrollElasticity, .none, "scrolling must not be disabled")
        XCTAssertLessThan(pane.view.fittingSize.height, 600, "pane fits a normal screen")
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        let own = (view as? NSScrollView).map { [$0] } ?? []
        return own + view.subviews.flatMap(scrollViews)
    }
}
