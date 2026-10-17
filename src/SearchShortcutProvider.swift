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

/// Items that depend on what was typed, and whether they go before or after the fuzzy matches.
struct QueryItems {
    var items: [ListItem] = []
    var afterMatches = false
}

/// A provider with items that depend on what was typed, merged into the results by SearchService.
protocol QueryListProvider {
    func items(for query: String) -> QueryItems
}

/// A shortcut picked from the results, with the query typed after its keyword.
struct SearchShortcutMatch {
    let shortcut: SearchShortcut
    let query: String
}

/**
 * Wraps the regular provider and adds a result for `<keyword> <query>`, e.g. "Search Google for 'swift'".
 */
class SearchShortcutProvider: ListProvider, QueryListProvider {
    let wrapped: ListProvider
    private let settings: SearchShortcutSettings
    private let launcher: TerminalLauncher
    private let openURL: (URL) -> Void
    private let isCommand: (String) -> Bool

    /// - Parameter isCommand: whether a word is a listed $PATH program; such input is likely a command,
    ///   e.g. `gh pr list`, so the shortcut goes after the regular matches.
    init(wrapping wrapped: ListProvider,
         settings: SearchShortcutSettings = .shared,
         isCommand: @escaping (String) -> Bool = { _ in false },
         launcher: TerminalLauncher = TerminalLauncher(),
         openURL: @escaping (URL) -> Void = { url in
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
         }) {
        self.wrapped = wrapped
        self.settings = settings
        self.launcher = launcher
        self.openURL = openURL
        self.isCommand = isCommand
    }

    func items(for query: String) -> QueryItems {
        let matches = settings.matches(for: query)
        guard let keyword = SearchShortcut.parse(query)?.keyword, !matches.isEmpty else { return QueryItems() }
        let items = matches.map { match in
            ListItem(name: match.shortcut.title(for: match.query),
                     data: SearchShortcutMatch(shortcut: match.shortcut, query: match.query))
        }
        return QueryItems(items: items, afterMatches: isCommand(keyword))
    }

    func get() -> [ListItem] {
        return wrapped.get()
    }

    func doAction(item: ListItem) {
        guard let match = item.data as? SearchShortcutMatch else {
            wrapped.doAction(item: item)
            return
        }
        let target = match.shortcut.expanded(with: match.query)
        switch match.shortcut.kind {
        case .url:
            guard let url = URL(string: target) else {
                NSLog("Invalid URL for shortcut %@: %@", match.shortcut.keyword, target)
                NSSound.beep()
                return
            }
            openURL(url)
        case .terminal:
            launcher.run(target)
        }
    }

    /// Shortcuts have no file to reveal or copy, so they ignore the modifier; everything else
    /// is forwarded with it so ⌘/⌥/⌃ Enter still reach the wrapped providers.
    func doAction(item: ListItem, action: ItemAction) {
        if item.data is SearchShortcutMatch {
            doAction(item: item)
        } else {
            wrapped.doAction(item: item, action: action)
        }
    }

    func doAction(input: String) {
        wrapped.doAction(input: input)
    }

    func cancel() {
        wrapped.cancel()
    }
}
