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
import Settings
import SwiftUI

/// Bridges `SearchShortcutSettings` to SwiftUI.
final class SearchShortcutsSettingsModel: ObservableObject {
    private let settings: SearchShortcutSettings

    @Published private(set) var shortcuts: [SearchShortcut]

    init(settings: SearchShortcutSettings = .shared) {
        self.settings = settings
        self.shortcuts = settings.shortcuts
    }

    /// Adds the shortcut, or replaces the one at `index`.
    func save(_ shortcut: SearchShortcut, at index: Int?) {
        if let index = index, shortcuts.indices.contains(index) {
            shortcuts[index] = shortcut
        } else {
            shortcuts.append(shortcut)
        }
        settings.shortcuts = shortcuts
    }

    func delete(at index: Int) {
        guard shortcuts.indices.contains(index) else { return }
        shortcuts.remove(at: index)
        settings.shortcuts = shortcuts
    }

    func restoreDefaults() {
        settings.restoreDefaults()
        shortcuts = settings.shortcuts
    }
}

/// The shortcut being added or edited in the sheet.
private struct EditingShortcut: Identifiable {
    let id = UUID()
    var index: Int?
    var shortcut: SearchShortcut
}

struct SearchShortcutsSettingsView: View {
    @StateObject private var model: SearchShortcutsSettingsModel
    @State private var selection: Int?
    @State private var editing: EditingShortcut?

    var body: some View {
        // Not a Form: a List inside a grouped Form is laid out as plain rows and never scrolls.
        VStack(alignment: .leading, spacing: 8) {
            Text("Search shortcuts")
                .font(.headline)

            List(selection: $selection) {
                ForEach(Array(model.shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    row(shortcut)
                        .tag(index)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { edit(index) }
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: Self.listHeight)

            HStack {
                Button {
                    editing = EditingShortcut(index: nil, shortcut: SearchShortcut(
                        keyword: "", name: "", template: "https://example.com/?q={query}", kind: .url))
                } label: {
                    Image(systemName: "plus")
                }
                Button {
                    if let index = selection {
                        model.delete(at: index)
                        selection = nil
                    }
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection == nil)
                Button("Edit…") {
                    if let index = selection { edit(index) }
                }
                .disabled(selection == nil)
                Spacer()
                Button("Restore Defaults") {
                    model.restoreDefaults()
                    selection = nil
                }
            }

            Text("Type a keyword, a space and a query, e.g. \"g swift actors\". "
                 + "In a template, {query} is replaced by what you typed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: SettingsLayout.paneWidth)
        .sheet(item: $editing) { item in
            SearchShortcutEditor(shortcut: item.shortcut) { shortcut in
                model.save(shortcut, at: item.index)
            }
        }
    }

    static let listHeight: CGFloat = 260

    init(settings: SearchShortcutSettings = .shared) {
        _model = StateObject(wrappedValue: SearchShortcutsSettingsModel(settings: settings))
    }

    private func row(_ shortcut: SearchShortcut) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(shortcut.keyword)
                .font(.body.monospaced())
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading) {
                Text(shortcut.name)
                Text(shortcut.template)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(shortcut.kind.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func edit(_ index: Int) {
        guard model.shortcuts.indices.contains(index) else { return }
        editing = EditingShortcut(index: index, shortcut: model.shortcuts[index])
    }
}

private struct SearchShortcutEditor: View {
    @State var shortcut: SearchShortcut
    let onSave: (SearchShortcut) -> Void
    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        SearchShortcut.isValidKeyword(shortcut.keyword)
            && !shortcut.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !shortcut.template.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .trailing) {
            Form {
                TextField("Keyword", text: $shortcut.keyword, prompt: Text("g"))
                TextField("Name", text: $shortcut.name, prompt: Text("Google"))
                Picker("Opens in", selection: $shortcut.kind) {
                    Text("Browser").tag(SearchShortcut.Kind.url)
                    Text("Terminal").tag(SearchShortcut.Kind.terminal)
                }
                TextField("Template", text: $shortcut.template, prompt: Text(prompt))
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    onSave(shortcut)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(width: 420)
    }

    private var prompt: String {
        shortcut.kind == .url ? "https://www.google.com/search?q={query}" : "claude {query}"
    }
}

extension SearchShortcutsSettingsView {
    static func pane(settings: SearchShortcutSettings = .shared) -> SettingsPane {
        Settings.PaneHostingController(pane: Settings.Pane(
            identifier: .shortcuts,
            title: "Shortcuts",
            toolbarIcon: NSImage(systemSymbolName: "magnifyingglass",
                                 accessibilityDescription: "Search shortcuts settings")!
        ) {
            SearchShortcutsSettingsView(settings: settings)
        })
    }
}
