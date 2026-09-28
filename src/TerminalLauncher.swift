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

/// How a command gets handed to a terminal.
enum LaunchPlan: Equatable {
    /// Terminal.app and iTerm2 take no command-line arguments, so they are scripted.
    case appleScript(String)
    /// Terminals that accept the program to run as launch arguments.
    case openApplication(bundleIdentifier: String, arguments: [String])
    /// User-provided template, run with /bin/sh.
    case shell(String)
}

/**
 * Opens a command in the user's terminal of choice
 */
class TerminalLauncher {
    private let settings: CommandSettings
    private let shell: String

    init(settings: CommandSettings = .shared, shell: String = TerminalLauncher.loginShell()) {
        self.settings = settings
        self.shell = shell
    }

    /// The user's login shell. $SHELL is not set for apps launched by launchd.
    static func loginShell() -> String {
        guard let shell = getpwuid(getuid())?.pointee.pw_shell else {
            return "/bin/zsh"
        }
        return String(cString: shell)
    }

    static func shellQuoted(_ str: String) -> String {
        return "'" + str.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptQuoted(_ str: String) -> String {
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    static func plan(for command: String, terminal: Terminal, shell: String, customTemplate: String) -> LaunchPlan {
        // Terminals launched by LaunchServices get a bare PATH, so run through an interactive login shell.
        let viaShell = [shell, "-l", "-i", "-c", command]
        let script = appleScriptQuoted(command)

        switch terminal {
        case .terminal:
            return .appleScript("""
                tell application "Terminal"
                    activate
                    do script \(script)
                end tell
                """)
        case .iterm2:
            return .appleScript("""
                tell application "iTerm"
                    activate
                    set newWindow to (create window with default profile)
                    tell current session of newWindow to write text \(script)
                end tell
                """)
        case .ghostty, .alacritty:
            return .openApplication(bundleIdentifier: terminal.bundleIdentifier!, arguments: ["-e"] + viaShell)
        case .kitty:
            return .openApplication(bundleIdentifier: terminal.bundleIdentifier!, arguments: viaShell)
        case .wezterm:
            return .openApplication(bundleIdentifier: terminal.bundleIdentifier!, arguments: ["start", "--"] + viaShell)
        case .custom:
            let quoted = shellQuoted(command)
            // A template without the placeholder would silently drop the command, so append it.
            guard customTemplate.contains(CommandSettings.placeholder) else {
                return .shell(customTemplate + " " + quoted)
            }
            return .shell(customTemplate.replacingOccurrences(of: CommandSettings.placeholder, with: quoted))
        }
    }

    /// Arguments for /usr/bin/open. Unlike NSWorkspace, `open` finishes the launch even if
    /// dmenu-mac exits right after, e.g. with --exit.
    static func openArguments(bundleIdentifier: String, arguments: [String]) -> [String] {
        return ["-n", "-b", bundleIdentifier, "--args"] + arguments
    }

    func run(_ command: String) {
        let plan = TerminalLauncher.plan(for: command, terminal: settings.terminal,
                                         shell: shell, customTemplate: settings.customTemplate)
        DispatchQueue.main.async {
            self.execute(plan)
        }
    }

    private func execute(_ plan: LaunchPlan) {
        switch plan {
        case .appleScript(let source):
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
            if let error = error {
                NSLog("Cannot run command in terminal: %@", error)
            }
        case .openApplication(let bundleIdentifier, let arguments):
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
                NSLog("Terminal %@ is not installed", bundleIdentifier)
                NSSound.beep()
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = TerminalLauncher.openArguments(bundleIdentifier: bundleIdentifier,
                                                               arguments: arguments)
            do {
                try process.run()
            } catch {
                NSLog("Cannot open terminal: %@", error.localizedDescription)
            }
        case .shell(let commandLine):
            // Login shell from the home directory, so the template sees the user's PATH.
            let process = AppListProvider.shellProcess(command: commandLine)
            do {
                try process.run()
            } catch {
                NSLog("Cannot run custom terminal command: %@", error.localizedDescription)
            }
        }
    }
}
