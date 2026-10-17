/*
 * Copyright (c) 2025 Jose Pereira <onaips@gmail.com>.
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

/**
 * Service class responsible for performing fuzzy search on list items
 * Separates search logic from view controller
 */
class SearchService {
    private let provider: ListProvider
    private let threshold: Double
    private let fuse: Fuse
    private let usage: UsageStore?

    /// Most a usage history can lower a fuzzy score (0 is a perfect match), so a much
    /// better match still beats a frequently used one.
    static let maxUsageBoost = 0.15

    init(provider: ListProvider, threshold: Double = 0.4, usage: UsageStore? = nil) {
        self.provider = provider
        self.threshold = threshold
        self.fuse = Fuse(threshold: threshold)
        self.usage = usage
    }

    /// Remembers a selection so it ranks higher next time.
    func recordSelection(_ item: ListItem) {
        usage?.record(item)
    }

    /**
     * Performs fuzzy search on items from the provider
     * - Parameter query: Search query string
     * - Returns: Array of matching items sorted by relevance
     */
    func search(query: String) -> [ListItem] {
        let items = provider.get()
        usage?.reload()

        // Empty query returns most used items first, then the rest alphabetically
        if query.isEmpty {
            return items
                .map { Ranked(item: $0, score: 0, usage: usage?.score(for: $0) ?? 0) }
                .sorted(by: SearchService.ranks)
                .map { $0.item }
        }

        // Perform fuzzy search
        let pattern = fuse.createPattern(from: query)
        var scoredItems: [Ranked] = []

        for item in items {
            if let result = fuse.search(pattern, in: item.name) {
                let itemUsage = usage?.score(for: item) ?? 0
                scoredItems.append(Ranked(item: item,
                                          score: result.score - SearchService.usageBoost(itemUsage),
                                          usage: itemUsage))
            }
        }

        // Sort by score (lower is better) and return items
        return scoredItems
            .sorted(by: SearchService.ranks)
            .map { $0.item }
    }

    /// Grows with usage but flattens out: 1 use ≈ 0.04, 7 uses ≈ 0.12, capped at maxUsageBoost.
    static func usageBoost(_ usage: Double) -> Double {
        guard usage > 0 else { return 0 }
        return min(maxUsageBoost, 0.04 * log2(1 + usage))
    }

    private struct Ranked {
        let item: ListItem
        /// Fuzzy score minus the usage boost; lower is better.
        let score: Double
        let usage: Double
    }

    private static func ranks(_ lhs: Ranked, _ rhs: Ranked) -> Bool {
        if lhs.score != rhs.score { return lhs.score < rhs.score }
        if lhs.usage != rhs.usage { return lhs.usage > rhs.usage }
        return lhs.item.name < rhs.item.name
    }
}
