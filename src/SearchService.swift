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

    init(provider: ListProvider, threshold: Double = 0.4) {
        self.provider = provider
        self.threshold = threshold
        self.fuse = Fuse(threshold: threshold)
    }

    /**
     * Performs fuzzy search on items from the provider
     * - Parameter query: Search query string
     * - Returns: Array of matching items sorted by relevance
     */
    func search(query: String) -> [ListItem] {
        let items = provider.get()

        // Empty query returns all items sorted alphabetically
        if query.isEmpty {
            return items.sorted { $0.name < $1.name }
        }

        // Perform fuzzy search
        let pattern = fuse.createPattern(from: query)
        var scoredItems: [(item: ListItem, score: Double)] = []

        for item in items {
            if let result = fuse.search(pattern, in: item.name) {
                scoredItems.append((item, result.score))
            }
        }

        // Sort by score (lower is better) and return items
        return scoredItems
            .sorted { $0.score < $1.score }
            .map { $0.item }
    }
}
