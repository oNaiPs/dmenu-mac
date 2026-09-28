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

import SwiftUI

/// Bridges `CommandSettings` to SwiftUI bindings.
final class CommandSettingsModel: ObservableObject {
    private let settings: CommandSettings

    init(settings: CommandSettings = .shared) {
        self.settings = settings
    }

    var enabled: Bool {
        get { settings.enabled }
        set { update { settings.enabled = newValue } }
    }

    var terminal: Terminal {
        get { settings.terminal }
        set { update { settings.terminal = newValue } }
    }

    /// The raw text being edited; an empty field means the default template.
    var customTemplate: String {
        get { settings.storedCustomTemplate }
        set { update { settings.customTemplate = newValue } }
    }

    var terminalPickerEnabled: Bool {
        enabled
    }

    var customTemplateEnabled: Bool {
        enabled && terminal == .custom
    }

    private func update(_ change: () -> Void) {
        objectWillChange.send()
        change()
    }
}
