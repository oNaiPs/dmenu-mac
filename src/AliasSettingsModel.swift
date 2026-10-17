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

/// Bridges `AliasSettings` to SwiftUI and validates edits.
final class AliasSettingsModel: ObservableObject {
    private let settings: AliasSettings
    private let itemNames: () -> [String]

    @Published private(set) var aliases: [Alias]

    /// - Parameter itemNames: names of the items an alias can point to
    init(settings: AliasSettings = .shared,
         itemNames: @escaping () -> [String] = AliasSettingsModel.launcherItemNames) {
        self.settings = settings
        self.itemNames = itemNames
        self.aliases = settings.aliases
    }

    /// Sorted, de-duplicated names of the items currently listed by the launcher.
    var targets: [String] {
        Array(Set(itemNames())).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func targets(matching filter: String) -> [String] {
        let filter = filter.trimmingCharacters(in: .whitespaces)
        let all = targets
        return filter.isEmpty ? all : all.filter { $0.localizedCaseInsensitiveContains(filter) }
    }

    func isMissing(_ alias: Alias) -> Bool {
        let names = itemNames()
        return !names.isEmpty && !names.contains(alias.target)
    }

    /// Returns why the alias can't be saved, or nil if it's fine.
    /// - Parameter replacing: id of the alias being edited, which may keep its own keyword
    func validationError(keyword: String, target: String, replacing: UUID? = nil) -> String? {
        if keyword.isEmpty {
            return "Enter a keyword."
        }
        if keyword.contains(where: { $0.isWhitespace }) {
            return "Keywords can't contain spaces."
        }
        if aliases.contains(where: { $0.id != replacing && $0.matchesExactly(keyword) }) {
            return "\"\(keyword)\" is already an alias."
        }
        if target.isEmpty {
            return "Pick a target."
        }
        let names = itemNames()
        if !names.isEmpty && !names.contains(target) {
            return "\"\(target)\" isn't in the list."
        }
        return nil
    }

    /// Adds a new alias, or replaces the one with the same id. Returns false if it's invalid.
    @discardableResult
    func save(_ alias: Alias) -> Bool {
        guard validationError(keyword: alias.keyword, target: alias.target, replacing: alias.id) == nil else {
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

    /// Items from the running launcher; empty when it's showing piped-in choices.
    static func launcherItemNames() -> [String] {
        guard let provider = (NSApp.delegate as? AppDelegate)?.searchViewController?.listProvider,
              !(provider is PipeListProvider) else {
            return []
        }
        return provider.get().map { $0.name }
    }
}
