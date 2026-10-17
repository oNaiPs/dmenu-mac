import XCTest
@testable import dmenu_mac

final class AliasSettingsModelTests: XCTestCase {
    private let suite = "AliasSettingsModelTests"
    private var defaults: UserDefaults!
    private var settings: AliasSettings!
    private var items: [String] = []
    private var model: AliasSettingsModel!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        settings = AliasSettings(defaults: defaults)
        items = ["Firefox", "Ghostty", "Safari", "Firefox"]
        model = AliasSettingsModel(settings: settings, itemNames: { [unowned self] in self.items })
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testTargetsAreSortedAndUnique() {
        XCTAssertEqual(model.targets, ["Firefox", "Ghostty", "Safari"])
        XCTAssertEqual(model.targets(matching: "fi"), ["Firefox"])
    }

    func testSaveAddsAndPersists() {
        XCTAssertTrue(model.save(Alias(keyword: "ff", target: "Firefox")))
        XCTAssertEqual(settings.aliases.map { $0.keyword }, ["ff"])
        XCTAssertEqual(AliasSettingsModel(settings: settings, itemNames: { [] }).aliases.count, 1)
    }

    func testSaveReplacesExistingAlias() {
        var alias = Alias(keyword: "ff", target: "Firefox")
        model.save(alias)
        alias.target = "Safari"
        XCTAssertTrue(model.save(alias))
        XCTAssertEqual(settings.aliases.map { $0.target }, ["Safari"])
    }

    func testDeleteRemovesAlias() {
        let alias = Alias(keyword: "ff", target: "Firefox")
        model.save(alias)
        model.delete(alias)
        XCTAssertTrue(model.aliases.isEmpty)
        XCTAssertTrue(settings.aliases.isEmpty)
    }

    func testValidation() {
        model.save(Alias(keyword: "ff", target: "Firefox"))

        XCTAssertNotNil(model.validationError(keyword: "", target: "Firefox"))
        XCTAssertNotNil(model.validationError(keyword: "f f", target: "Firefox"))
        XCTAssertNotNil(model.validationError(keyword: "FF", target: "Safari"), "duplicate, case-insensitive")
        XCTAssertNotNil(model.validationError(keyword: "sf", target: ""))
        XCTAssertNotNil(model.validationError(keyword: "sf", target: "Netscape"))
        XCTAssertNil(model.validationError(keyword: "sf", target: "Safari"))
        XCTAssertNil(model.validationError(keyword: "ff", target: "Safari", replacing: model.aliases[0].id))
        XCTAssertFalse(model.save(Alias(keyword: "", target: "Safari")))
    }

    func testAnyTargetAcceptedWhenListIsUnavailable() {
        items = []
        XCTAssertNil(model.validationError(keyword: "x", target: "Whatever"))
        XCTAssertFalse(model.isMissing(Alias(keyword: "x", target: "Whatever")))
    }

    func testMissingTargetIsFlagged() {
        XCTAssertTrue(model.isMissing(Alias(keyword: "x", target: "Netscape")))
        XCTAssertFalse(model.isMissing(Alias(keyword: "x", target: "Safari")))
    }
}
