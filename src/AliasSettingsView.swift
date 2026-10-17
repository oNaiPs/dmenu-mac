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

struct AliasSettingsView: View {
    @StateObject private var model = AliasSettingsModel()
    @State private var editing: Alias?

    static let listHeight: CGFloat = 260

    var body: some View {
        // Not a Form: a List inside a grouped Form is laid out as plain rows and never scrolls.
        VStack(alignment: .leading, spacing: 8) {
            Text("Aliases")
                .font(.headline)

            List {
                ForEach(model.aliases) { alias in
                    row(alias)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(height: Self.listHeight)
            .overlay {
                if model.aliases.isEmpty {
                    Text("No aliases yet.")
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text("Typing an alias exactly shows its target first, e.g. ff for Firefox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Add Alias…") {
                    editing = Alias(keyword: "", target: "")
                }
            }
        }
        .padding(20)
        .frame(width: SettingsLayout.paneWidth)
        .sheet(item: $editing) { alias in
            AliasEditor(model: model, alias: alias) { editing = nil }
        }
    }

    private func row(_ alias: Alias) -> some View {
        HStack {
            Text(alias.keyword)
                .font(.body.monospaced())
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
            Text(alias.target)
            if model.isMissing(alias) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.yellow)
                    .help("\(alias.target) isn't in the list right now")
            }
            Spacer()
            Button {
                editing = alias
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit")
            Button {
                model.delete(alias)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
    }
}

/// Sheet for adding or editing one alias, with a searchable list of targets.
struct AliasEditor: View {
    @ObservedObject var model: AliasSettingsModel
    @State private var alias: Alias
    @State private var filter: String
    let dismiss: () -> Void

    init(model: AliasSettingsModel, alias: Alias, dismiss: @escaping () -> Void) {
        self.model = model
        self._alias = State(initialValue: alias)
        self._filter = State(initialValue: "")
        self.dismiss = dismiss
    }

    private var error: String? {
        model.validationError(for: alias)
    }

    /// Selected row; name-only aliases from older versions select the first item with that name.
    private var selection: Binding<String?> {
        Binding(
            get: { alias.targetID ?? model.targets.first { $0.name == alias.target }?.id },
            set: { id in
                let target = model.targets.first { $0.id == id }
                alias.target = target?.name ?? ""
                alias.targetID = target?.id
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Form {
                TextField("Keyword", text: $alias.keyword, prompt: Text("ff"))
                LabeledContent("Target") {
                    Text(alias.target.isEmpty ? "None" : alias.target)
                        .foregroundStyle(alias.target.isEmpty ? .secondary : .primary)
                }
            }

            TextField("Search items", text: $filter)
                .textFieldStyle(.roundedBorder)

            List(model.targets(matching: filter), selection: selection) { target in
                HStack {
                    Text(target.name)
                    Spacer()
                    Text(target.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .frame(height: 220)

            HStack {
                if let error, !alias.keyword.isEmpty || !alias.target.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Spacer()
                Button("Cancel", role: .cancel, action: dismiss)
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    if model.save(alias) {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(error != nil)
            }
        }
        .padding()
        .frame(width: 380)
    }
}

extension AliasSettingsView {
    static func pane() -> SettingsPane {
        Settings.PaneHostingController(pane: Settings.Pane(
            identifier: .aliases,
            title: "Aliases",
            toolbarIcon: NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: "Alias settings")!
        ) {
            AliasSettingsView()
        })
    }
}
