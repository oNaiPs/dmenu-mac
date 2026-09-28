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

// MARK: - UserDefaults Keys
extension UserDefaults {
    enum CommandKeys {
        static let enabled = "commands.enabled"
        static let terminal = "commands.terminal"
        static let customTemplate = "commands.customTemplate"
    }
}

extension Notification.Name {
    static let commandSettingsChanged = Notification.Name("commandSettingsChanged")
}

/// Terminal used to run command-line programs picked from $PATH.
enum Terminal: String, CaseIterable {
    case terminal
    case iterm2
    case ghostty
    case alacritty
    case kitty
    case wezterm
    case custom

    var displayName: String {
        switch self {
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        case .ghostty: return "Ghostty"
        case .alacritty: return "Alacritty"
        case .kitty: return "kitty"
        case .wezterm: return "WezTerm"
        case .custom: return "Custom command"
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .ghostty: return "com.mitchellh.ghostty"
        case .alacritty: return "org.alacritty"
        case .kitty: return "net.kovidgoyal.kitty"
        case .wezterm: return "com.github.wez.wezterm"
        case .custom: return nil
        }
    }
}

class CommandSettings {
    static let shared = CommandSettings()

    /// Placeholder replaced by the shell-quoted command in a custom template.
    static let placeholder = "{cmd}"
    static let defaultCustomTemplate = "open -na Alacritty --args -e /bin/zsh -lic {cmd}"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Lists programs from $PATH next to apps. Off by default so apps aren't buried under `ls` and friends.
    var enabled: Bool {
        get { defaults.bool(forKey: UserDefaults.CommandKeys.enabled) }
        set { set(newValue, forKey: UserDefaults.CommandKeys.enabled) }
    }

    var terminal: Terminal {
        get {
            defaults.string(forKey: UserDefaults.CommandKeys.terminal).flatMap(Terminal.init) ?? .terminal
        }
        set { set(newValue.rawValue, forKey: UserDefaults.CommandKeys.terminal) }
    }

    /// Template used to launch commands; a blank one falls back to the default.
    var customTemplate: String {
        get {
            let template = storedCustomTemplate.trimmingCharacters(in: .whitespaces)
            return template.isEmpty ? Self.defaultCustomTemplate : template
        }
        set { set(newValue, forKey: UserDefaults.CommandKeys.customTemplate) }
    }

    /// The template exactly as the user typed it, for editing.
    var storedCustomTemplate: String {
        defaults.string(forKey: UserDefaults.CommandKeys.customTemplate) ?? ""
    }

    private func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: .commandSettingsChanged, object: self)
    }
}
