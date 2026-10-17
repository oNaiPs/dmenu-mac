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

import Cocoa
import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

enum SystemSettingsURL {
    static let keyboardShortcuts = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts")!
    static let automation = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @StateObject private var commands = CommandSettingsModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(model.step.title)
                    .font(.title2.bold())
                Spacer()
                Text("\(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Group {
                switch model.step {
                case .welcome: welcome
                case .launchAtLogin: launchAtLogin
                case .terminal: terminal
                case .done: done
                }
            }
            // Wrap long text instead of truncating it; the window grows to fit.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if !model.step.isFirst {
                    Button("Back") { model.back() }
                }
                Spacer()
                if model.step.isLast {
                    Button("Get Started") { model.finish() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Skip") { model.advance() }
                        .keyboardShortcut(.cancelAction)
                    Button("Continue") { model.advance() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
        .frame(minHeight: 360)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Picks up a change made in System Settings.
            model.refreshAutomationStatus()
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dmenu-mac opens a launcher bar when you press its hotkey. Type a few letters, " +
                 "press Enter, and the app opens. This takes a minute; every step can be skipped " +
                 "and changed later in Settings.")
            Form {
                KeyboardShortcuts.Recorder("Global shortcut", name: .activateSearch)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            Text("⌘ Space is also Spotlight's shortcut, and Spotlight wins. Pick another shortcut " +
                 "above, or turn Spotlight's off under Keyboard Shortcuts → Spotlight.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open Keyboard Shortcuts…") {
                NSWorkspace.shared.open(SystemSettingsURL.keyboardShortcuts)
            }
        }
    }

    private var launchAtLogin: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dmenu-mac waits in the menu bar for its hotkey. Start it at login so the hotkey " +
                 "always works.")
            Form {
                LaunchAtLogin.Toggle("Launch at login")
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var terminal: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dmenu-mac can also list command-line programs such as nvim or htop and open them " +
                 "in your terminal.")
            Form {
                Toggle("List programs from $PATH", isOn: $commands.enabled)
                Picker("Terminal", selection: $commands.terminal) {
                    ForEach(Terminal.allCases, id: \.self) { terminal in
                        Text(terminal.displayName).tag(terminal)
                    }
                }
                .disabled(!commands.terminalPickerEnabled)
                if commands.customTemplateEnabled {
                    TextField("Custom command", text: $commands.customTemplate,
                              prompt: Text(CommandSettings.defaultCustomTemplate))
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .onChange(of: commands.enabled) { _ in model.refreshAutomationStatus() }
            .onChange(of: commands.terminal) { _ in model.refreshAutomationStatus() }

            if let target = model.automationTarget {
                automationAccess(for: target)
            }
        }
    }

    private func automationAccess(for target: Terminal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(target.displayName) is controlled with Apple Events, which macOS asks you to allow once.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                statusLabel
                Spacer()
                switch model.automationStatus {
                case .denied:
                    Button("Open Automation Settings…") {
                        NSWorkspace.shared.open(SystemSettingsURL.automation)
                    }
                case .granted, .notInstalled:
                    EmptyView()
                default:
                    Button("Grant Access") { model.requestAutomationAccess() }
                        .disabled(model.isRequestingAccess)
                }
            }
            if model.automationStatus == .notRunning {
                Text("\(target.displayName) opens in the background so macOS can ask.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var statusLabel: some View {
        if model.isRequestingAccess {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Waiting for your answer…")
            }
        } else if let status = model.automationStatus {
            Label(status.summary, systemImage: status.symbolName)
                .foregroundStyle(status == .granted ? .green : status == .denied ? .red : .secondary)
        }
    }

    private var done: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Press your shortcut anywhere and start typing.")
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(Self.cheatSheet, id: \.0) { key, action in
                    GridRow {
                        Text(key).bold()
                        Text(action)
                    }
                }
            }
            Text("Run this setup again any time from the menu bar icon.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    static let cheatSheet: [(String, String)] = [
        ("Tab / →", "Next result"),
        ("Shift Tab / ←", "Previous result"),
        ("Enter", "Open the result, or run what you typed"),
        ("Shift Enter", "Run what you typed"),
        ("Esc", "Hide the launcher"),
        ("⌘ ,", "Settings")
    ]
}

private extension AutomationStatus {
    var symbolName: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }
}

/// Hosts the wizard in a small standalone window.
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    static let shared = OnboardingWindowController()

    let model: OnboardingModel

    init(model: OnboardingModel = OnboardingModel()) {
        self.model = model
        let window = NSWindow(contentViewController: NSHostingController(rootView: OnboardingView(model: model)))
        window.styleMask = [.titled, .closable]
        window.title = "dmenu-mac Setup"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        super.init(window: window)
        window.delegate = self
        model.onFinish = { [weak self] in self?.close() }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window = window else { return }
        let reopening = !window.isVisible
        if reopening {
            model.restart()
        }
        // dmenu-mac is a menu bar app, so it has to pull itself forward.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        if reopening, let content = window.contentViewController?.view {
            // SwiftUI sizes the window lazily; size it first so center() uses the real frame.
            window.setContentSize(content.fittingSize)
            window.center()
        }
    }

    /// Esc on a page without a Skip button (the last one) closes the wizard.
    override func cancelOperation(_ sender: Any?) {
        model.finish()
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the window counts as done, so it doesn't come back on every launch.
        model.markCompleted()
    }
}

extension AppDelegate {
    /// Opens the wizard on the first launch as an app, once the launcher has read its arguments.
    func showOnboardingIfNeeded(settings: OnboardingSettings = .shared) {
        guard !OnboardingGate.isRunningTests else { return }
        DispatchQueue.main.async { [weak self] in
            guard let controller = self?.searchViewController else { return }
            let show = OnboardingGate.shouldShow(
                completed: settings.completed,
                launchedAsApp: getppid() == 1,
                exitOnClose: controller.exitOnClose,
                readsFromPipe: controller.listProvider is PipeListProvider)
            if show {
                OnboardingWindowController.shared.show()
            }
        }
    }

    @objc func runSetup() {
        OnboardingWindowController.shared.show()
    }
}
