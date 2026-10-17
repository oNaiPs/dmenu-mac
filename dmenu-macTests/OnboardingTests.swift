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

private final class MockAutomationPermissions: AutomationPermissions {
    var currentStatus: AutomationStatus = .notDetermined
    var requestResult: AutomationStatus = .granted
    private(set) var statusQueries: [String] = []
    private(set) var requests: [String] = []
    /// Held back so tests can look at the in-flight state.
    private(set) var pendingCompletion: ((AutomationStatus) -> Void)?

    func status(for bundleIdentifier: String) -> AutomationStatus {
        statusQueries.append(bundleIdentifier)
        return currentStatus
    }

    func requestAccess(for bundleIdentifier: String, completion: @escaping (AutomationStatus) -> Void) {
        requests.append(bundleIdentifier)
        pendingCompletion = completion
    }

    func answer() {
        pendingCompletion?(requestResult)
        pendingCompletion = nil
    }
}

final class OnboardingTests: XCTestCase {
    private let suiteName = "dmenu-mac.OnboardingTests"
    private var defaults: UserDefaults!
    private var settings: OnboardingSettings!
    private var commands: CommandSettings!
    private var permissions: MockAutomationPermissions!
    private var model: OnboardingModel!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        settings = OnboardingSettings(defaults: defaults)
        commands = CommandSettings(defaults: defaults)
        permissions = MockAutomationPermissions()
        model = OnboardingModel(settings: settings, commands: commands, permissions: permissions)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        model = nil
        permissions = nil
        commands = nil
        settings = nil
        defaults = nil
        super.tearDown()
    }

    // MARK: - Gating

    func testShowsOnFirstLaunchAsApp() {
        XCTAssertTrue(OnboardingGate.shouldShow(completed: false, launchedAsApp: true, exitOnClose: false,
                                                readsFromPipe: false, isTesting: false))
    }

    func testHiddenOnceCompleted() {
        XCTAssertFalse(OnboardingGate.shouldShow(completed: true, launchedAsApp: true, exitOnClose: false,
                                                 readsFromPipe: false, isTesting: false))
    }

    func testHiddenWhenStartedFromShell() {
        XCTAssertFalse(OnboardingGate.shouldShow(completed: false, launchedAsApp: false, exitOnClose: false,
                                                 readsFromPipe: false, isTesting: false),
                       "--no-exit from a shell still isn't an app launch")
        XCTAssertFalse(OnboardingGate.shouldShow(completed: false, launchedAsApp: true, exitOnClose: true,
                                                 readsFromPipe: false, isTesting: false),
                       "--exit is a one-shot run")
    }

    func testHiddenInPipeMode() {
        XCTAssertFalse(OnboardingGate.shouldShow(completed: false, launchedAsApp: true, exitOnClose: false,
                                                 readsFromPipe: true, isTesting: false))
    }

    func testHiddenUnderXCTest() {
        XCTAssertTrue(OnboardingGate.isRunningTests)
        XCTAssertFalse(OnboardingGate.shouldShow(completed: false, launchedAsApp: true, exitOnClose: false,
                                                 readsFromPipe: false))
    }

    // MARK: - Persistence

    func testNotCompletedByDefault() {
        XCTAssertFalse(settings.completed)
    }

    func testFinishPersistsCompletion() {
        var finished = false
        model.onFinish = { finished = true }

        model.finish()

        XCTAssertTrue(finished)
        XCTAssertTrue(OnboardingSettings(defaults: defaults).completed)
    }

    // MARK: - Steps

    func testStepsInOrder() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .launchAtLogin, .terminal, .done])
        XCTAssertTrue(OnboardingStep.welcome.isFirst)
        XCTAssertTrue(OnboardingStep.done.isLast)
        XCTAssertNil(OnboardingStep.welcome.previous)
        XCTAssertNil(OnboardingStep.done.next)
    }

    func testAdvanceWalksEveryStepThenFinishes() {
        var finished = false
        model.onFinish = { finished = true }

        var seen = [model.step]
        for _ in 1..<OnboardingStep.allCases.count {
            model.advance()
            seen.append(model.step)
        }
        XCTAssertEqual(seen, OnboardingStep.allCases)
        XCTAssertFalse(finished)
        XCTAssertFalse(settings.completed)

        model.advance()
        XCTAssertTrue(finished)
        XCTAssertTrue(settings.completed)
    }

    func testBackStopsAtFirstStep() {
        model.advance()
        model.back()
        XCTAssertEqual(model.step, .welcome)
        model.back()
        XCTAssertEqual(model.step, .welcome)
    }

    func testRestartGoesToWelcome() {
        model.advance()
        model.advance()
        model.restart()
        XCTAssertEqual(model.step, .welcome)
    }

    // MARK: - Automation

    func testOnlyScriptedTerminalsNeedAutomation() {
        let scripted = Terminal.allCases.filter(\.usesAppleEvents)
        XCTAssertEqual(scripted, [.terminal, .iterm2])
        // Must agree with how TerminalLauncher actually runs each terminal.
        for terminal in Terminal.allCases {
            let plan = TerminalLauncher.plan(for: "ls", terminal: terminal, shell: "/bin/zsh",
                                             customTemplate: "x {cmd}")
            if case .appleScript = plan {
                XCTAssertTrue(terminal.usesAppleEvents, terminal.rawValue)
            } else {
                XCTAssertFalse(terminal.usesAppleEvents, terminal.rawValue)
            }
        }
    }

    func testNoAutomationTargetWhenCommandsDisabled() {
        commands.terminal = .terminal
        XCTAssertNil(model.automationTarget)
    }

    func testNoAutomationTargetForArgumentTerminals() {
        commands.enabled = true
        commands.terminal = .kitty
        XCTAssertNil(model.automationTarget)
        model.refreshAutomationStatus()
        XCTAssertNil(model.automationStatus)
        XCTAssertTrue(permissions.statusQueries.isEmpty)
    }

    func testReachingTerminalStepChecksStatusWithoutPrompting() {
        commands.enabled = true
        commands.terminal = .iterm2
        permissions.currentStatus = .denied

        model.advance()
        model.advance()

        XCTAssertEqual(model.step, .terminal)
        XCTAssertEqual(permissions.statusQueries, ["com.googlecode.iterm2"])
        XCTAssertTrue(permissions.requests.isEmpty)
        XCTAssertEqual(model.automationStatus, .denied)
    }

    func testRequestAccessReportsResult() {
        commands.enabled = true
        commands.terminal = .terminal
        permissions.requestResult = .granted

        model.requestAutomationAccess()
        XCTAssertTrue(model.isRequestingAccess)
        model.requestAutomationAccess()
        XCTAssertEqual(permissions.requests, ["com.apple.Terminal"], "one prompt at a time")

        permissions.answer()
        XCTAssertFalse(model.isRequestingAccess)
        XCTAssertEqual(model.automationStatus, .granted)
    }

    func testRequestResultIgnoredAfterTerminalChanged() {
        commands.enabled = true
        commands.terminal = .terminal
        model.refreshAutomationStatus()

        model.requestAutomationAccess()
        commands.terminal = .iterm2
        permissions.answer()

        XCTAssertEqual(model.automationStatus, .notDetermined)
    }

    func testStatusMapsOSStatus() {
        XCTAssertEqual(AutomationStatus(osStatus: noErr), .granted)
        XCTAssertEqual(AutomationStatus(osStatus: -1743), .denied)
        XCTAssertEqual(AutomationStatus(osStatus: -1744), .notDetermined)
        XCTAssertEqual(AutomationStatus(osStatus: -600), .notRunning)
        XCTAssertEqual(AutomationStatus(osStatus: -50), .failed(-50))
    }
}

private final class MockApplication: ActivationPolicyApplying {
    private(set) var policies: [NSApplication.ActivationPolicy] = []
    private(set) var broughtToFront = 0

    func applyActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        policies.append(policy)
    }

    func bringToFront() {
        broughtToFront += 1
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
