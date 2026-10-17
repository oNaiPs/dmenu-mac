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

final class MockAutomationPermissions: AutomationPermissions {
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

    func testNewInstallStillGetsTheWizard() {
        settings.markCompletedIfUpgrading()
        XCTAssertFalse(settings.completed)
        XCTAssertNil(defaults.object(forKey: OnboardingSettings.completedKey), "left undecided")
    }

    func testUpgradeIsMarkedCompleted() {
        let priorInstalls: [String] = [
            "KeyboardShortcuts_activateSearchGlobalShortcut",
            kLegacyKc,
            UserDefaults.CommandKeys.terminal,
            "appearance.fontSize"
        ]
        for key in priorInstalls {
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set("x", forKey: key)

            settings.markCompletedIfUpgrading()

            XCTAssertTrue(settings.completed, key)
        }
    }

    func testQuittingMidWayShowsItAgainNextLaunch() {
        // First launch of a new install: nothing stored, so the wizard opens.
        settings.markCompletedIfUpgrading()
        settings.markStarted()
        // The hotkey setup writes its key; then the user quits with the wizard open.
        defaults.set("x", forKey: "KeyboardShortcuts_activateSearchGlobalShortcut")

        let nextLaunch = OnboardingSettings(defaults: defaults)
        nextLaunch.markCompletedIfUpgrading()

        XCTAssertFalse(nextLaunch.completed)
        XCTAssertTrue(OnboardingGate.shouldShow(completed: nextLaunch.completed, launchedAsApp: true,
                                                exitOnClose: false, readsFromPipe: false, isTesting: false))
    }

    func testMarkStartedKeepsCompletion() {
        settings.completed = true
        settings.markStarted()
        XCTAssertTrue(settings.completed)
    }

    func testUpgradeCheckLeavesAnExplicitAnswerAlone() {
        settings.completed = false
        defaults.set(true, forKey: UserDefaults.CommandKeys.enabled)

        settings.markCompletedIfUpgrading()

        XCTAssertFalse(settings.completed, "only decides when nothing is stored yet")
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
