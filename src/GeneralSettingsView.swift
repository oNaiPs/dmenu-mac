/*
 * Copyright (c) 2023 Jose Pereira <onaips@gmail.com>.
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
import Settings
import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @StateObject private var commands = CommandSettingsModel()

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Global shortcut", name: .activateSearch)

            Section {
                Toggle("List programs from $PATH", isOn: $commands.enabled)

                Picker("Terminal", selection: $commands.terminal) {
                    ForEach(Terminal.allCases, id: \.self) { terminal in
                        Text(terminal.displayName).tag(terminal)
                    }
                }
                .disabled(!commands.terminalPickerEnabled)

                TextField("Custom command", text: $commands.customTemplate,
                          prompt: Text(CommandSettings.defaultCustomTemplate))
                    .disabled(!commands.customTemplateEnabled)
            } header: {
                Text("Command-line programs")
            } footer: {
                Text("Programs open in the terminal. In a custom command, {cmd} is replaced by the command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: SettingsLayout.paneWidth)
    }
}

extension GeneralSettingsView {
    static func pane() -> SettingsPane {
        Settings.PaneHostingController(pane: Settings.Pane(
            identifier: .general,
            title: "General",
            toolbarIcon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General settings")!
        ) {
            GeneralSettingsView()
        })
    }
}

enum SettingsLayout {
    static let paneWidth: CGFloat = 480
}
