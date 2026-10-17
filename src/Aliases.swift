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

extension ListItem {
    /// Stable identity for an alias target: the file path for apps and panes,
    /// the command for $PATH programs, and the name for anything else.
    var aliasIdentity: String {
        switch providerData {
        case let url as URL where url.isFileURL:
            return url.path
        case let command as Command:
            return "cmd:" + command.commandLine
        default:
            return "name:" + name
        }
    }
}

/// A short keyword that brings up a listed item, e.g. `ff` for Firefox.
struct Alias: Codable, Equatable, Identifiable {
    var id = UUID()
    var keyword: String
    /// Name of the target as shown in the list, kept for display.
    var target: String
    /// `ListItem.aliasIdentity` of the target. Aliases saved before this existed only have the name.
    var targetID: String?

    init(keyword: String, target: String, targetID: String? = nil) {
        self.keyword = keyword
        self.target = target
        self.targetID = targetID
    }

    init(keyword: String, item: ListItem) {
        self.init(keyword: keyword, target: item.name, targetID: item.aliasIdentity)
    }

    func matchesExactly(_ query: String) -> Bool {
        keyword.caseInsensitiveCompare(query) == .orderedSame
    }

    func isTarget(_ item: ListItem) -> Bool {
        if let targetID {
            return item.aliasIdentity == targetID
        }
        return item.name == target
    }

    func resolve(in items: [ListItem]) -> ListItem? {
        items.first(where: isTarget)
    }
}

extension UserDefaults {
    enum AliasKeys {
        static let aliases = "aliases"
    }
}

/// Where aliases are kept: UserDefaults, or memory only (used under XCTest so tests
/// never see the aliases of whoever runs them).
class AliasSettings {
    static let shared: AliasSettings = {
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        return isTesting ? .inMemory() : AliasSettings(defaults: .standard)
    }()

    private let defaults: UserDefaults?
    private var stored: [Alias] = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private init() {
        self.defaults = nil
    }

    static func inMemory(_ aliases: [Alias] = []) -> AliasSettings {
        let settings = AliasSettings()
        settings.aliases = aliases
        return settings
    }

    var aliases: [Alias] {
        get {
            guard let defaults else { return stored }
            guard let data = defaults.data(forKey: UserDefaults.AliasKeys.aliases) else { return [] }
            return (try? JSONDecoder().decode([Alias].self, from: data)) ?? []
        }
        set {
            guard let defaults else {
                stored = newValue
                return
            }
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
    private let settings: AliasSettings
    private let fuse: Fuse

    init(provider: ListProvider, settings: AliasSettings = .shared, threshold: Double = 0.4,
         usage: UsageStore? = nil) {
        self.provider = provider
        self.settings = settings
        self.fuse = Fuse(threshold: threshold)
        super.init(provider: provider, threshold: threshold, usage: usage)
    }

    /// Aliases only make sense for the app list, not for choices piped in on stdin.
    static func make(provider: ListProvider, settings: AliasSettings = .shared,
                     usage: UsageStore? = nil) -> SearchService {
        provider is PipeListProvider
            ? SearchService(provider: provider, usage: usage)
            : AliasSearchService(provider: provider, settings: settings, usage: usage)
    }

    override func search(query: String) -> [ListItem] {
        var results = super.search(query: query)
        let aliases = settings.aliases
        guard !query.isEmpty, !aliases.isEmpty else { return results }

        let items = provider.get()
        var listed = Set<String>()

        // Exact alias hits go first, moved up from wherever fuzzy search put them.
        var exact: [ListItem] = []
        for alias in aliases where alias.matchesExactly(query) {
            guard let target = alias.resolve(in: items), listed.insert(target.aliasIdentity).inserted else {
                continue
            }
            exact.append(target)
            results.removeAll { $0.aliasIdentity == target.aliasIdentity }
        }
        results.forEach { listed.insert($0.aliasIdentity) }

        // Targets of aliases that fuzzily match follow the regular results, if not already listed.
        let pattern = fuse.createPattern(from: query)
        let extra = aliases
            .filter { !$0.matchesExactly(query) }
            .compactMap { alias in fuse.search(pattern, in: alias.keyword).map { (alias, $0.score) } }
            .sorted { $0.1 < $1.1 }
            .compactMap { $0.0.resolve(in: items) }
            .filter { listed.insert($0.aliasIdentity).inserted }

        return exact + results + extra
    }
}
