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
import Fuse

/// A short keyword that brings up a listed item, e.g. `ff` for Firefox.
struct Alias: Codable, Equatable, Identifiable {
    var id = UUID()
    var keyword: String
    /// Name of the target item as it appears in the list.
    var target: String

    func matchesExactly(_ query: String) -> Bool {
        keyword.caseInsensitiveCompare(query) == .orderedSame
    }
}

extension UserDefaults {
    enum AliasKeys {
        static let aliases = "aliases"
    }
}

class AliasSettings {
    static let shared = AliasSettings()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var aliases: [Alias] {
        get {
            guard let data = defaults.data(forKey: UserDefaults.AliasKeys.aliases) else { return [] }
            return (try? JSONDecoder().decode([Alias].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: UserDefaults.AliasKeys.aliases)
            }
        }
    }
}

/**
 * Search that puts an alias's target first when the query is exactly that alias,
 * and also finds targets whose alias fuzzily matches the query.
 */
final class AliasSearchService: SearchService {
    private let provider: ListProvider
    private let aliases: () -> [Alias]
    private let fuse: Fuse

    init(provider: ListProvider,
         aliases: @escaping () -> [Alias] = { AliasSettings.shared.aliases },
         threshold: Double = 0.4) {
        self.provider = provider
        self.aliases = aliases
        self.fuse = Fuse(threshold: threshold)
        super.init(provider: provider, threshold: threshold)
    }

    /// Aliases only make sense for the app list, not for choices piped in on stdin.
    static func make(provider: ListProvider) -> SearchService {
        provider is PipeListProvider ? SearchService(provider: provider) : AliasSearchService(provider: provider)
    }

    override func search(query: String) -> [ListItem] {
        var results = super.search(query: query)
        let aliases = self.aliases()
        guard !query.isEmpty, !aliases.isEmpty else { return results }

        let items = provider.get()
        func item(named name: String) -> ListItem? { items.first { $0.name == name } }

        // Exact alias hits go first, moved up from wherever fuzzy search put them.
        var exact: [ListItem] = []
        for alias in aliases where alias.matchesExactly(query) {
            guard !exact.contains(where: { $0.name == alias.target }), let target = item(named: alias.target) else {
                continue
            }
            exact.append(target)
            if let index = results.firstIndex(where: { $0.name == alias.target }) {
                results.remove(at: index)
            }
        }

        // Targets of aliases that fuzzily match follow the regular results, if not already listed.
        let pattern = fuse.createPattern(from: query)
        let fuzzy = aliases
            .filter { !$0.matchesExactly(query) }
            .compactMap { alias in fuse.search(pattern, in: alias.keyword).map { (alias, $0.score) } }
            .sorted { $0.1 < $1.1 }
            .compactMap { item(named: $0.0.target) }

        var listed = Set((exact + results).map { $0.name })
        let extra = fuzzy.filter { listed.insert($0.name).inserted }

        return exact + results + extra
    }
}
