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

/// A provider with items that depend on what was typed. SearchService puts them above the fuzzy matches.
protocol QueryListProvider {
    func items(for query: String) -> [ListItem]
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

    init(wrapping wrapped: ListProvider,
         settings: SearchShortcutSettings = .shared,
         launcher: TerminalLauncher = TerminalLauncher(),
         openURL: @escaping (URL) -> Void = { url in
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
         }) {
        self.wrapped = wrapped
        self.settings = settings
        self.launcher = launcher
        self.openURL = openURL
    }

    func items(for query: String) -> [ListItem] {
        return settings.matches(for: query).map { match in
            ListItem(name: match.shortcut.title(for: match.query),
                     data: SearchShortcutMatch(shortcut: match.shortcut, query: match.query))
        }
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

    func doAction(input: String) {
        wrapped.doAction(input: input)
    }

    func cancel() {
        wrapped.cancel()
    }
}
