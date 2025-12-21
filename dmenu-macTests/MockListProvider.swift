import Foundation
@testable import dmenu_mac

/// Mock ListProvider for testing
class MockListProvider: ListProvider {
    var mockItems: [ListItem] = []
    var actionCallCount = 0
    var lastActionedItem: ListItem?

    init(items: [ListItem] = []) {
        self.mockItems = items
    }

    func get() -> [ListItem] {
        return mockItems
    }

    func doAction(item: ListItem) {
        actionCallCount += 1
        lastActionedItem = item
    }
}
