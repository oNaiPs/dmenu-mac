import XCTest
@testable import dmenu_mac

final class AliasSettingsModelTests: XCTestCase {
    private var settings: AliasSettings!
    private var items: [ListItem] = []
    private var model: AliasSettingsModel!

    override func setUp() {
        super.setUp()
        settings = .inMemory()
        items = [
            ListItem(name: "Firefox", data: URL(fileURLWithPath: "/Applications/Firefox.app")),
            ListItem(name: "Ghostty", data: URL(fileURLWithPath: "/Applications/Ghostty.app")),
            ListItem(name: "Safari", data: URL(fileURLWithPath: "/Applications/Safari.app")),
            ListItem(name: "Firefox", data: URL(fileURLWithPath: "/Applications/Firefox.app")),
            ListItem(name: "Firefox", data: URL(fileURLWithPath: "/Users/me/Applications/Firefox.app")),
            ListItem(name: "nvim", data: Command(commandLine: "nvim"))
        ]
        model = AliasSettingsModel(settings: settings, items: { [unowned self] in self.items })
    }

    private func alias(_ keyword: String, _ index: Int) -> Alias {
        Alias(keyword: keyword, item: items[index])
    }

    func testTargetsAreSortedAndUniqueByIdentity() {
        XCTAssertEqual(model.targets.map { $0.name }, ["Firefox", "Firefox", "Ghostty", "nvim", "Safari"])
        XCTAssertEqual(model.targets(matching: "fi").map { $0.id },
                       ["/Applications/Firefox.app", "/Users/me/Applications/Firefox.app"])
        XCTAssertEqual(model.targets.first { $0.name == "nvim" }?.detail, "$PATH")
        XCTAssertEqual(model.targets.first?.detail, "/Applications")
    }

    func testSaveAddsAndPersists() {
        XCTAssertTrue(model.save(alias("ff", 0)))
        XCTAssertEqual(settings.aliases.map { $0.keyword }, ["ff"])
        XCTAssertEqual(settings.aliases.first?.targetID, "/Applications/Firefox.app")
        XCTAssertEqual(AliasSettingsModel(settings: settings, items: { [] }).aliases.count, 1)
    }

    func testSaveReplacesExistingAlias() {
        var edited = alias("ff", 0)
        model.save(edited)
        edited.target = "Safari"
        edited.targetID = "/Applications/Safari.app"
        XCTAssertTrue(model.save(edited))
        XCTAssertEqual(settings.aliases.map { $0.targetID }, ["/Applications/Safari.app"])
    }

    func testDeleteRemovesAlias() {
        let saved = alias("ff", 0)
        model.save(saved)
        model.delete(saved)
        XCTAssertTrue(model.aliases.isEmpty)
        XCTAssertTrue(settings.aliases.isEmpty)
    }

    func testValidation() {
        model.save(alias("ff", 0))

        XCTAssertNotNil(model.validationError(for: alias("", 0)))
        XCTAssertNotNil(model.validationError(for: alias("f f", 0)))
        XCTAssertNotNil(model.validationError(for: alias("FF", 2)), "duplicate, case-insensitive")
        XCTAssertNotNil(model.validationError(for: Alias(keyword: "sf", target: "")))
        XCTAssertNotNil(model.validationError(for: Alias(keyword: "sf", target: "Netscape", targetID: "/x.app")))
        XCTAssertNil(model.validationError(for: alias("sf", 2)))

        var edited = model.aliases[0]
        edited.target = "Safari"
        edited.targetID = "/Applications/Safari.app"
        XCTAssertNil(model.validationError(for: edited), "an alias may keep its own keyword")
        XCTAssertFalse(model.save(alias("", 2)))
    }

    func testKeywordOfAliasWithMissingTargetCanBeEdited() {
        var saved = alias("vi", 5)
        model.save(saved)
        items.removeLast() // $PATH programs turned off

        saved.keyword = "v"
        XCTAssertNil(model.validationError(for: saved))
        XCTAssertTrue(model.save(saved))

        saved.target = "Netscape"
        saved.targetID = "/Applications/Netscape.app"
        XCTAssertNotNil(model.validationError(for: saved), "a newly picked target must exist")
    }

    func testAnyTargetAcceptedWhenListIsUnavailable() {
        items = []
        XCTAssertNil(model.validationError(for: Alias(keyword: "x", target: "Whatever")))
        XCTAssertFalse(model.isMissing(Alias(keyword: "x", target: "Whatever")))
    }

    func testMissingTargetIsFlagged() {
        XCTAssertTrue(model.isMissing(Alias(keyword: "x", target: "Netscape")))
        XCTAssertTrue(model.isMissing(Alias(keyword: "x", target: "Safari", targetID: "/gone/Safari.app")))
        XCTAssertFalse(model.isMissing(Alias(keyword: "x", target: "Safari")), "name-only aliases match by name")
        XCTAssertFalse(model.isMissing(alias("x", 5)))
    }
}
