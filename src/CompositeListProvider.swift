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

/**
 * Merge several providers into one list, routing each action back to the provider that owns the item
 */
class CompositeListProvider: ListProvider {
    fileprivate struct Tagged: UsageIdentifiable, FileURLRepresentable {
        let providerIndex: Int
        let data: Any?

        var usageKey: String? { (data as? UsageIdentifiable)?.usageKey }
        var fileURL: URL? { (data as? FileURLRepresentable)?.fileURL }
    }

    let providers: [ListProvider]
    let inputProvider: ListProvider?

    /// - Parameter inputProvider: receives typed input; defaults to the first provider
    init(providers: [ListProvider], inputProvider: ListProvider? = nil) {
        self.providers = providers
        self.inputProvider = inputProvider ?? providers.first
    }

    func get() -> [ListItem] {
        return providers.enumerated().flatMap { index, provider in
            provider.get().map { tag($0, index) }
        }
    }

    func doAction(input: String) {
        inputProvider?.doAction(input: input)
    }

    func doAction(item: ListItem) {
        doAction(item: item, action: .open)
    }

    func doAction(item: ListItem, action: ItemAction) {
        guard let tagged = item.data as? Tagged, providers.indices.contains(tagged.providerIndex) else {
            NSLog("Cannot do action on item \(item.name)")
            return
        }
        providers[tagged.providerIndex].doAction(item: ListItem(name: item.name, data: tagged.data), action: action)
    }

    func cancel() {
        providers.forEach { $0.cancel() }
    }

    private func tag(_ item: ListItem, _ index: Int) -> ListItem {
        return ListItem(name: item.name, data: Tagged(providerIndex: index, data: item.data))
    }
}

extension ListItem {
    /// The data the owning provider attached, without CompositeListProvider's routing tag.
    var providerData: Any? {
        (data as? CompositeListProvider.Tagged)?.data ?? data
    }
}
