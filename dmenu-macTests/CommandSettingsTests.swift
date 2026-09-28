import XCTest
@testable import dmenu_mac

final class CommandSettingsTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!
    var settings: CommandSettings!

    override func setUp() {
        super.setUp()
        suiteName = "CommandSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = CommandSettings(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        settings = nil
        defaults = nil
        super.tearDown()
    }

    func testDefaults() {
        XCTAssertFalse(settings.enabled, "Commands are opt-in so apps aren't buried")
        XCTAssertEqual(settings.terminal, .terminal)
        XCTAssertEqual(settings.customTemplate, CommandSettings.defaultCustomTemplate)
    }

    func testValuesRoundTrip() {
        settings.enabled = true
        settings.terminal = .kitty
        settings.customTemplate = "foot {cmd}"

        let reloaded = CommandSettings(defaults: defaults)
        XCTAssertTrue(reloaded.enabled)
        XCTAssertEqual(reloaded.terminal, .kitty)
        XCTAssertEqual(reloaded.customTemplate, "foot {cmd}")
    }

    func testBlankTemplateFallsBackToDefault() {
        settings.customTemplate = "   "
        XCTAssertEqual(settings.customTemplate, CommandSettings.defaultCustomTemplate)
        XCTAssertEqual(settings.storedCustomTemplate, "   ")
    }

    func testUnknownTerminalFallsBackToTerminalApp() {
        defaults.set("xterm", forKey: UserDefaults.CommandKeys.terminal)
        XCTAssertEqual(settings.terminal, .terminal)
    }

    func testChangesPostNotification() {
        expectation(forNotification: .commandSettingsChanged, object: settings)
        settings.enabled = true
        waitForExpectations(timeout: 1)
    }

    func testEveryTerminalHasNameAndAllButCustomHaveBundleIdentifier() {
        for terminal in Terminal.allCases {
            XCTAssertFalse(terminal.displayName.isEmpty)
            XCTAssertEqual(terminal.bundleIdentifier == nil, terminal == .custom)
        }
    }
}
