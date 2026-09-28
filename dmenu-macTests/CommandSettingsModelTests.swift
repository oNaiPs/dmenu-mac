import XCTest
import Combine
@testable import dmenu_mac

final class CommandSettingsModelTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!
    var settings: CommandSettings!
    var model: CommandSettingsModel!

    override func setUp() {
        super.setUp()
        suiteName = "CommandSettingsModelTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        settings = CommandSettings(defaults: defaults)
        model = CommandSettingsModel(settings: settings)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        model = nil
        settings = nil
        defaults = nil
        super.tearDown()
    }

    func testReflectsDefaults() {
        XCTAssertFalse(model.enabled)
        XCTAssertEqual(model.terminal, .terminal)
        XCTAssertEqual(model.customTemplate, "", "An empty field shows the default as its placeholder")
        XCTAssertFalse(model.terminalPickerEnabled, "Terminal is irrelevant while commands are off")
        XCTAssertFalse(model.customTemplateEnabled)
    }

    func testChangesAreStored() {
        model.enabled = true
        model.terminal = .wezterm
        model.customTemplate = "foot {cmd}"

        XCTAssertTrue(settings.enabled)
        XCTAssertEqual(settings.terminal, .wezterm)
        XCTAssertEqual(settings.customTemplate, "foot {cmd}")
    }

    func testTemplateKeepsSpacesWhileTyping() {
        model.customTemplate = "foot "
        XCTAssertEqual(model.customTemplate, "foot ")
    }

    func testClearedTemplateFallsBackToDefault() {
        model.customTemplate = "foot {cmd}"
        model.customTemplate = ""
        XCTAssertEqual(settings.customTemplate, CommandSettings.defaultCustomTemplate)
    }

    func testOnlyCustomTerminalEnablesTemplate() {
        model.enabled = true
        XCTAssertTrue(model.terminalPickerEnabled)
        XCTAssertFalse(model.customTemplateEnabled)

        model.terminal = .custom
        XCTAssertTrue(model.customTemplateEnabled)
    }

    func testChangesPublish() {
        var changes = 0
        let cancellable = model.objectWillChange.sink { changes += 1 }
        model.enabled = true
        model.terminal = .kitty
        XCTAssertEqual(changes, 2)
        cancellable.cancel()
    }
}
