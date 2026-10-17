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

/// Item data that has a stable identity worth remembering across launches.
/// Items without one (e.g. piped stdin choices) are never recorded.
protocol UsageIdentifiable {
    var usageKey: String? { get }
}

extension URL: UsageIdentifiable {
    var usageKey: String? { isFileURL ? "file:" + standardizedFileURL.path : absoluteString }
}

extension Command: UsageIdentifiable {
    var usageKey: String? { "cmd:" + commandLine }
}

extension ListItem {
    var usageKey: String? { (data as? UsageIdentifiable)?.usageKey }
}

/**
 * Remembers which items the user opens, as a frecency score: each selection adds 1 and
 * the total halves every `halfLife`, so frequent and recent picks both rank higher.
 */
class UsageStore {
    static let shared = UsageStore(defaults: UsageStore.defaultDefaults())

    /// Tests get a throwaway suite so they never touch the user's real history.
    private static func defaultDefaults() -> UserDefaults {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else { return .standard }
        let suite = "dmenu-mac.tests.usage"
        UserDefaults().removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }

    static let defaultsKey = "usageHistory"
    /// Scores below this are dropped when saving, so the history doesn't grow forever.
    static let pruneThreshold = 0.05

    private let defaults: UserDefaults
    private let halfLife: TimeInterval
    private let now: () -> Date
    private var entries: [String: Entry]

    private struct Entry {
        var score: Double
        var lastUsed: Date
    }

    init(defaults: UserDefaults = .standard,
         halfLife: TimeInterval = 14 * 24 * 60 * 60,
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.halfLife = halfLife
        self.now = now
        self.entries = UsageStore.load(from: defaults)
    }

    /// Current frecency of an item, 0 if never used.
    func score(for item: ListItem) -> Double {
        guard let key = item.usageKey, let entry = entries[key] else { return 0 }
        return decayed(entry)
    }

    /// Picks up selections saved by other dmenu-mac processes, e.g. short-lived skhd runs
    /// next to the menu bar instance.
    func reload() {
        entries = UsageStore.load(from: defaults)
    }

    func record(_ item: ListItem) {
        guard let key = item.usageKey else { return }
        // Read-modify-write so another process's records aren't overwritten.
        reload()
        let current = entries[key].map(decayed) ?? 0
        entries[key] = Entry(score: current + 1, lastUsed: now())
        save()
    }

    private func decayed(_ entry: Entry) -> Double {
        let age = max(0, now().timeIntervalSince(entry.lastUsed))
        return entry.score * pow(0.5, age / halfLife)
    }

    private func save() {
        entries = entries.filter { decayed($0.value) >= UsageStore.pruneThreshold }
        let plist = entries.mapValues { ["score": $0.score, "lastUsed": $0.lastUsed.timeIntervalSince1970] }
        defaults.set(plist, forKey: UsageStore.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> [String: Entry] {
        guard let plist = defaults.dictionary(forKey: defaultsKey) as? [String: [String: Double]] else {
            return [:]
        }
        return plist.compactMapValues { value in
            guard let score = value["score"], let lastUsed = value["lastUsed"] else { return nil }
            return Entry(score: score, lastUsed: Date(timeIntervalSince1970: lastUsed))
        }
    }
}
