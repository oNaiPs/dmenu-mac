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

/// A keyword that turns `<keyword> <query>` into a web search or a terminal command.
struct SearchShortcut: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        /// Opens the template, with the query percent-encoded, in the default browser.
        case url
        /// Runs the template, with the query shell-quoted, in the configured terminal.
        case terminal

        var displayName: String {
            switch self {
            case .url: return "Web"
            case .terminal: return "Terminal"
            }
        }
    }

    /// Replaced by the query in a template. Templates without it get the query appended.
    static let placeholder = "{query}"

    var keyword: String
    var name: String
    var template: String
    var kind: Kind

    /// Title shown in the results list for a query.
    func title(for query: String) -> String {
        switch kind {
        case .url: return "Search \(name) for '\(query)'"
        case .terminal: return "Run \(name) with '\(query)'"
        }
    }

    /// The template with the query filled in: percent-encoded for URLs, shell-quoted for commands.
    func expanded(with query: String) -> String {
        let value: String
        switch kind {
        case .url: value = Self.percentEncoded(query)
        case .terminal: value = TerminalLauncher.shellQuoted(query)
        }
        guard template.contains(Self.placeholder) else {
            return kind == .terminal ? template + " " + value : template + value
        }
        return template.replacingOccurrences(of: Self.placeholder, with: value)
    }

    /// Only RFC 3986 unreserved characters pass through, so `&`, `#`, `+` and spaces can't break the URL.
    static func percentEncoded(_ str: String) -> String {
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return str.addingPercentEncoding(withAllowedCharacters: unreserved) ?? str
    }

    /// Splits `"g swift actors"` into `("g", "swift actors")`. Nil without a keyword, a space and a query.
    static func parse(_ input: String) -> (keyword: String, query: String)? {
        let trimmed = input.drop { $0 == " " }
        guard let space = trimmed.firstIndex(of: " ") else { return nil }
        let keyword = String(trimmed[..<space])
        let query = trimmed[space...].trimmingCharacters(in: .whitespaces)
        guard !keyword.isEmpty, !query.isEmpty else { return nil }
        return (keyword, query)
    }

    /// A keyword is a single word.
    static func isValidKeyword(_ keyword: String) -> Bool {
        return !keyword.isEmpty && keyword.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }

    /// Keywords avoid names of common command-line programs (`gh`, `claude`), so typed commands still run.
    static let defaults: [SearchShortcut] = [
        SearchShortcut(keyword: "g", name: "Google",
                       template: "https://www.google.com/search?q={query}", kind: .url),
        SearchShortcut(keyword: "ddg", name: "DuckDuckGo",
                       template: "https://duckduckgo.com/?q={query}", kind: .url),
        SearchShortcut(keyword: "ghs", name: "GitHub",
                       template: "https://github.com/search?q={query}", kind: .url),
        SearchShortcut(keyword: "yt", name: "YouTube",
                       template: "https://www.youtube.com/results?search_query={query}", kind: .url),
        SearchShortcut(keyword: "w", name: "Wikipedia",
                       template: "https://en.wikipedia.org/w/index.php?search={query}", kind: .url),
        SearchShortcut(keyword: "c", name: "Claude",
                       template: "https://claude.ai/new?q={query}", kind: .url),
        SearchShortcut(keyword: "gpt", name: "ChatGPT",
                       template: "https://chatgpt.com/?q={query}", kind: .url),
        SearchShortcut(keyword: "chatgpt", name: "ChatGPT",
                       template: "https://chatgpt.com/?q={query}", kind: .url),
        SearchShortcut(keyword: "p", name: "Perplexity",
                       template: "https://www.perplexity.ai/search?q={query}", kind: .url),
        SearchShortcut(keyword: "cc", name: "Claude Code",
                       template: "claude {query}", kind: .terminal),
        SearchShortcut(keyword: "cx", name: "Codex",
                       template: "codex {query}", kind: .terminal)
    ]
}

extension UserDefaults {
    enum SearchShortcutKeys {
        static let shortcuts = "searchShortcuts.list"
    }
}

/// Persists the shortcut list in UserDefaults; the defaults apply until the user edits it.
class SearchShortcutSettings {
    /// Under XCTest this uses a scratch suite, so tests never read or change the user's shortcuts.
    static let shared: SearchShortcutSettings = {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil else {
            return SearchShortcutSettings()
        }
        let suiteName = "dmenu-mac.tests.searchShortcuts"
        UserDefaults().removePersistentDomain(forName: suiteName)
        return SearchShortcutSettings(defaults: UserDefaults(suiteName: suiteName)!)
    }()

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shortcuts: [SearchShortcut] {
        get {
            guard let data = defaults.data(forKey: UserDefaults.SearchShortcutKeys.shortcuts),
                  let stored = try? JSONDecoder().decode([LenientShortcut].self, from: data) else {
                return SearchShortcut.defaults
            }
            // Entries that no longer decode, e.g. an unknown kind, are skipped rather than losing the list.
            return stored.compactMap(\.shortcut)
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: UserDefaults.SearchShortcutKeys.shortcuts)
        }
    }

    func restoreDefaults() {
        defaults.removeObject(forKey: UserDefaults.SearchShortcutKeys.shortcuts)
    }

    /// Shortcuts whose keyword matches the input, case-insensitively, paired with the query.
    func matches(for input: String) -> [(shortcut: SearchShortcut, query: String)] {
        guard let parsed = SearchShortcut.parse(input) else { return [] }
        let keyword = parsed.keyword.lowercased()
        return shortcuts
            .filter { $0.keyword.lowercased() == keyword }
            .map { ($0, parsed.query) }
    }
}

/// Decodes one stored shortcut, yielding nil instead of failing the whole list.
private struct LenientShortcut: Decodable {
    let shortcut: SearchShortcut?

    init(from decoder: Decoder) throws {
        shortcut = try? SearchShortcut(from: decoder)
    }
}
