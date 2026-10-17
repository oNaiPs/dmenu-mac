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

import Foundation

/// Pages of the first-run setup wizard, in order.
enum OnboardingStep: Int, CaseIterable {
    case welcome
    case launchAtLogin
    case terminal
    case done

    var title: String {
        switch self {
        case .welcome: return "Welcome to dmenu-mac"
        case .launchAtLogin: return "Launch at Login"
        case .terminal: return "Terminal Programs"
        case .done: return "You're All Set"
        }
    }

    var isFirst: Bool { self == Self.allCases.first }
    var isLast: Bool { self == Self.allCases.last }

    var next: OnboardingStep? { Self(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { Self(rawValue: rawValue - 1) }
}

/// Remembers whether the setup wizard has been seen.
final class OnboardingSettings {
    static let shared = OnboardingSettings()
    static let completedKey = "onboarding.completed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var completed: Bool {
        get { defaults.bool(forKey: Self.completedKey) }
        set { defaults.set(newValue, forKey: Self.completedKey) }
    }
}

/// Decides whether the wizard opens on its own at launch.
enum OnboardingGate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Only for the app opened by LaunchServices (Finder, Dock, login item) and never for
    /// one-shot runs from a shell, a hotkey daemon or a pipe, where a window would get in the way.
    static func shouldShow(completed: Bool, launchedAsApp: Bool, exitOnClose: Bool,
                           readsFromPipe: Bool, isTesting: Bool = isRunningTests) -> Bool {
        return !completed && launchedAsApp && !exitOnClose && !readsFromPipe && !isTesting
    }
}

/// Automation (Apple Events) consent for one target app, as reported by TCC.
enum AutomationStatus: Equatable {
    case granted
    case denied
    case notDetermined
    /// macOS only answers for a running app; asking launches it first.
    case notRunning
    case notInstalled
    case failed(OSStatus)

    // AppleEvents.h constants, spelled out so this file needs no Carbon import.
    static let errAEEventNotPermitted: OSStatus = -1743
    static let errAEEventWouldRequireUserConsent: OSStatus = -1744
    static let procNotFound: OSStatus = -600

    init(osStatus: OSStatus) {
        switch osStatus {
        case noErr: self = .granted
        case Self.errAEEventNotPermitted: self = .denied
        case Self.errAEEventWouldRequireUserConsent: self = .notDetermined
        case Self.procNotFound: self = .notRunning
        default: self = .failed(osStatus)
        }
    }

    var summary: String {
        switch self {
        case .granted: return "Access granted"
        case .denied: return "Access denied"
        case .notDetermined, .notRunning: return "Not determined yet"
        case .notInstalled: return "Not installed"
        case .failed(let code): return "Could not check access (error \(code))"
        }
    }
}

/// TCC access behind a seam so the wizard can be tested without real consent prompts.
protocol AutomationPermissions {
    /// Current consent, never prompting.
    func status(for bundleIdentifier: String) -> AutomationStatus
    /// Shows the consent prompt if the user hasn't answered yet. Calls back on the main queue.
    func requestAccess(for bundleIdentifier: String, completion: @escaping (AutomationStatus) -> Void)
}

extension Terminal {
    /// Terminals that TerminalLauncher drives through Apple Events, which need Automation consent.
    var usesAppleEvents: Bool {
        self == .terminal || self == .iterm2
    }
}

/// State and navigation of the setup wizard.
final class OnboardingModel: ObservableObject {
    @Published private(set) var step: OnboardingStep = .welcome
    @Published private(set) var automationStatus: AutomationStatus?
    @Published private(set) var isRequestingAccess = false

    private let settings: OnboardingSettings
    private let commands: CommandSettings
    private let permissions: AutomationPermissions
    var onFinish: (() -> Void)?

    init(settings: OnboardingSettings = .shared, commands: CommandSettings = .shared,
         permissions: AutomationPermissions = SystemAutomationPermissions()) {
        self.settings = settings
        self.commands = commands
        self.permissions = permissions
    }

    /// Continue and Skip both move on; settings are applied as they are changed.
    func advance() {
        guard let next = step.next else {
            finish()
            return
        }
        step = next
        if step == .terminal {
            refreshAutomationStatus()
        }
    }

    func back() {
        if let previous = step.previous {
            step = previous
        }
    }

    func restart() {
        step = .welcome
    }

    func finish() {
        markCompleted()
        onFinish?()
    }

    func markCompleted() {
        settings.completed = true
    }

    /// The terminal that needs Automation consent, if the current setup scripts one.
    var automationTarget: Terminal? {
        let terminal = commands.terminal
        return commands.enabled && terminal.usesAppleEvents ? terminal : nil
    }

    func refreshAutomationStatus() {
        guard let bundleIdentifier = automationTarget?.bundleIdentifier else {
            automationStatus = nil
            return
        }
        automationStatus = permissions.status(for: bundleIdentifier)
    }

    func requestAutomationAccess() {
        guard let bundleIdentifier = automationTarget?.bundleIdentifier, !isRequestingAccess else { return }
        isRequestingAccess = true
        permissions.requestAccess(for: bundleIdentifier) { [weak self] status in
            self?.isRequestingAccess = false
            // The terminal may have been changed while the prompt was up.
            if self?.automationTarget?.bundleIdentifier == bundleIdentifier {
                self?.automationStatus = status
            }
        }
    }
}
