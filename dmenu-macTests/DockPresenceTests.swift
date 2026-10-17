/*
 * Copyright (c) 2026 Jose Pereira <onaips@gmail.com>.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import XCTest
@testable import dmenu_mac

private final class MockApplication: ActivationPolicyApplying {
    private(set) var policies: [NSApplication.ActivationPolicy] = []
    private(set) var broughtToFront = 0
    /// Everything in call order, to check that the policy changes before activation.
    private(set) var log: [String] = []
    private var nextTurn: [() -> Void] = []

    func applyActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        policies.append(policy)
        log.append(policy == .regular ? "regular" : "accessory")
    }

    func bringToFront() {
        broughtToFront += 1
        log.append("activate")
    }

    func onNextTurn(_ work: @escaping () -> Void) {
        nextTurn.append(work)
        log.append("scheduled")
    }

    func runNextTurn() {
        let work = nextTurn
        nextTurn = []
        work.forEach { $0() }
    }
}

final class DockPresenceTests: XCTestCase {
    private let suiteName = "dmenu-mac.DockPresenceTests"
    private var defaults: UserDefaults!
    private var app: MockApplication!
    private var presence: DockPresence!
    private var controller: OnboardingWindowController!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        app = MockApplication()
        presence = DockPresence(app: app, previousAppProvider: { nil })
        let model = OnboardingModel(settings: OnboardingSettings(defaults: defaults),
                                    commands: CommandSettings(defaults: defaults),
                                    permissions: MockAutomationPermissions())
        controller = OnboardingWindowController(model: model, dockPresence: presence)
    }

    override func tearDown() {
        controller.window?.orderOut(nil)
        defaults.removePersistentDomain(forName: suiteName)
        controller = nil
        presence = nil
        app = nil
        defaults = nil
        super.tearDown()
    }

    private func showWizard() throws -> NSWindow {
        controller.show()
        let window = try XCTUnwrap(controller.window)
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(app.policies, [.regular], "in the Dock while the wizard is open")
        XCTAssertEqual(app.broughtToFront, 1)
        XCTAssertTrue(presence.isActive)
        return window
    }

    private func assertBackToAccessory(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.policies, [.regular, .accessory], file: file, line: line)
        XCTAssertFalse(presence.isActive, file: file, line: line)
        XCTAssertFalse(controller.window?.isVisible ?? true, file: file, line: line)
        XCTAssertTrue(OnboardingSettings(defaults: defaults).completed, file: file, line: line)
    }

    func testPolicySwitchesBeforeActivatingAndActivatesAgainNextTurn() throws {
        let window = try showWizard()
        XCTAssertEqual(app.log, ["regular", "activate", "scheduled"])

        window.resignKey()
        app.runNextTurn()

        XCTAssertEqual(app.log, ["regular", "activate", "scheduled", "activate"],
                       "a refused first activation is retried once the policy has taken effect")
        XCTAssertTrue(window.isVisible)
    }

    func testNoRetryAfterClosingBeforeNextTurn() throws {
        _ = try showWizard()
        controller.close()
        app.runNextTurn()
        XCTAssertEqual(app.log, ["regular", "activate", "scheduled", "accessory"])
        XCTAssertFalse(controller.window?.isVisible ?? true, "a late retry must not reopen it")
    }

    func testNothingChangesUntilShown() {
        XCTAssertTrue(app.policies.isEmpty)
        XCTAssertFalse(presence.reopen())
    }

    func testFinishRestoresAccessory() throws {
        _ = try showWizard()
        controller.model.finish()
        assertBackToAccessory()
    }

    func testEscOnLastPageRestoresAccessory() throws {
        _ = try showWizard()
        controller.cancelOperation(nil)
        assertBackToAccessory()
    }

    func testCloseButtonRestoresAccessory() throws {
        let window = try showWizard()
        window.performClose(nil)
        assertBackToAccessory()
    }

    func testCommandWRestoresAccessory() throws {
        let window = try showWizard()
        let event = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0,
            windowNumber: window.windowNumber, context: nil, characters: "w",
            charactersIgnoringModifiers: "w", isARepeat: false, keyCode: 13))

        XCTAssertTrue(window.performKeyEquivalent(with: event))
        assertBackToAccessory()
    }

    func testShowingAgainDoesNotStackPolicies() throws {
        _ = try showWizard()
        controller.show()
        XCTAssertEqual(app.policies, [.regular])
        controller.close()
        assertBackToAccessory()
    }

    func testReopenBringsWindowBack() throws {
        let window = try showWizard()
        window.orderOut(nil)

        XCTAssertTrue(presence.reopen())
        XCTAssertTrue(window.isVisible)
        XCTAssertEqual(app.broughtToFront, 2)
    }

    func testStaysRegularUntilLastWindowCloses() throws {
        _ = try showWizard()
        let other = NSWindow(contentRect: .init(x: 0, y: 0, width: 100, height: 100),
                             styleMask: [.titled, .closable], backing: .buffered, defer: true)
        other.isReleasedWhenClosed = false
        presence.show(other)
        XCTAssertEqual(app.policies, [.regular])

        controller.close()
        XCTAssertEqual(app.policies, [.regular], "Settings is still open")
        other.close()
        XCTAssertEqual(app.policies, [.regular, .accessory])
    }
}
