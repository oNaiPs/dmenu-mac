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

/// An item an alias can point to, as shown in the Settings picker.
struct AliasTarget: Identifiable, Hashable {
    let id: String
    let name: String
    /// Disambiguates items with the same name, e.g. the app's folder.
    let detail: String
}

/// Bridges `AliasSettings` to SwiftUI and validates edits.
final class AliasSettingsModel: ObservableObject {
    private let settings: AliasSettings
    private let items: () -> [ListItem]

    @Published private(set) var aliases: [Alias]

    /// - Parameter items: the items an alias can point to
    init(settings: AliasSettings = .shared,
         items: @escaping () -> [ListItem] = AliasSettingsModel.launcherItems) {
        self.settings = settings
        self.items = items
        self.aliases = settings.aliases
    }

    /// The launcher's items, one per identity, sorted by name.
    var targets: [AliasTarget] {
        var seen = Set<String>()
        return items()
            .filter { seen.insert($0.aliasIdentity).inserted }
            .map { AliasTarget(id: $0.aliasIdentity, name: $0.name, detail: Self.detail(for: $0)) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func targets(matching filter: String) -> [AliasTarget] {
        let filter = filter.trimmingCharacters(in: .whitespaces)
        let all = targets
        return filter.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    func isMissing(_ alias: Alias) -> Bool {
        let items = items()
        return !items.isEmpty && alias.resolve(in: items) == nil
    }

    /// Returns why the alias can't be saved, or nil if it's fine.
    /// An alias may keep its own keyword when edited (same id).
    func validationError(for alias: Alias) -> String? {
        let keyword = alias.keyword
        if keyword.isEmpty {
            return "Enter a keyword."
        }
        if keyword.contains(where: { $0.isWhitespace }) {
            return "Keywords can't contain spaces."
        }
        if aliases.contains(where: { $0.id != alias.id && $0.matchesExactly(keyword) }) {
            return "\"\(keyword)\" is already an alias."
        }
        if alias.target.isEmpty {
            return "Pick a target."
        }
        // A saved target may be missing for now ($PATH listing off, list still loading),
        // so only check it when it changed; otherwise the keyword couldn't be edited.
        let stored = aliases.first { $0.id == alias.id }
        let targetChanged = stored?.targetID != alias.targetID || stored?.target != alias.target
        if targetChanged && isMissing(alias) {
            return "\"\(alias.target)\" isn't in the list."
        }
        return nil
    }

    /// Adds a new alias, or replaces the one with the same id. Returns false if it's invalid.
    @discardableResult
    func save(_ alias: Alias) -> Bool {
        guard validationError(for: alias) == nil else {
            return false
        }
        if let index = aliases.firstIndex(where: { $0.id == alias.id }) {
            aliases[index] = alias
        } else {
            aliases.append(alias)
        }
        settings.aliases = aliases
        return true
    }

    func delete(_ alias: Alias) {
        aliases.removeAll { $0.id == alias.id }
        settings.aliases = aliases
    }

    static func detail(for item: ListItem) -> String {
        switch item.providerData {
        case let url as URL where url.isFileURL:
            return url.deletingLastPathComponent().path
        case is Command:
            return "$PATH"
        default:
            return ""
        }
    }

    /// Items from the running launcher; empty when it's showing piped-in choices.
    static func launcherItems() -> [ListItem] {
        guard let provider = (NSApp.delegate as? AppDelegate)?.searchViewController?.listProvider,
              !(provider is PipeListProvider) else {
            return []
        }
        return provider.get()
    }
}
