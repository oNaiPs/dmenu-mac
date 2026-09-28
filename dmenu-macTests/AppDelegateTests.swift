import XCTest
import ServiceManagement
import Settings
@testable import dmenu_mac

final class AppDelegateTests: XCTestCase {
    private var appDelegate: AppDelegate {
        // swiftlint:disable:next force_cast
        NSApp.delegate as! AppDelegate
    }

    func testStatusItemUsesTemplateImage() throws {
        let button = try XCTUnwrap(appDelegate.statusItem.button)
        let image = try XCTUnwrap(button.image)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(button.title, "")
    }

    func testStatusMenuHasSettingsWithCommandComma() throws {
        let menu = try XCTUnwrap(appDelegate.statusItem.menu)
        let settings = try XCTUnwrap(menu.items.first { $0.action == #selector(AppDelegate.openSettings) })
        XCTAssertEqual(settings.title, "Settings…")
        XCTAssertEqual(settings.keyEquivalent, ",")
        XCTAssertEqual(settings.keyEquivalentModifierMask, .command)
    }

    func testLaunchAtLoginMenuItemReflectsLoginItemStatus() throws {
        let menu = try XCTUnwrap(appDelegate.statusItem.menu)
        appDelegate.startAtLaunch.state = .mixed

        appDelegate.menuNeedsUpdate(menu)

        let expected: NSControl.StateValue = SMAppService.mainApp.status == .enabled ? .on : .off
        XCTAssertEqual(appDelegate.startAtLaunch.state, expected)
    }

    func testResumeAppReusesStoryboardLauncher() throws {
        let controller = try XCTUnwrap(appDelegate.searchViewController)
        let window = try XCTUnwrap(controller.view.window)
        window.orderOut(nil)

        appDelegate.resumeApp()

        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(window.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(appDelegate.searchViewController === controller)
        let launchers = NSApp.windows.filter { $0.contentViewController is SearchViewController }
        XCTAssertEqual(launchers.count, 1)
        window.orderOut(nil)
    }

    func testCommandCommaInSearchWindowOpensSettings() throws {
        let window = SearchWindow()
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: 0, context: nil, characters: ",", charactersIgnoringModifiers: ",",
            isARepeat: false, keyCode: 43))

        XCTAssertTrue(window.performKeyEquivalent(with: event))

        let settingsWindow = NSApp.windows.first { $0.windowController is SettingsWindowController }
        XCTAssertEqual(settingsWindow?.isVisible, true)
        settingsWindow?.close()
    }
}
