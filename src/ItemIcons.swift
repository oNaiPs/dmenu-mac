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

/// Item data backed by a file on disk (an app, a settings pane), which therefore has an icon.
protocol FileURLRepresentable {
    var fileURL: URL? { get }
}

extension URL: FileURLRepresentable {
    var fileURL: URL? { isFileURL ? self : nil }
}

extension ListItem {
    /// The file this item opens, if any. Typed commands and piped choices have none.
    var fileURL: URL? { (data as? FileURLRepresentable)?.fileURL }
}

/// Finder icons per path. `NSWorkspace` icons hold every resolution, so one image serves all sizes.
final class IconCache {
    static let shared = IconCache()

    private let cache = NSCache<NSString, NSImage>()

    func icon(for url: URL) -> NSImage {
        let path = url.path
        if let icon = cache.object(forKey: path as NSString) {
            return icon
        }
        let icon = NSWorkspace.shared.icon(forFile: Self.iconSource(for: url).path)
        cache.setObject(icon, forKey: path as NSString)
        return icon
    }

    /// Drops every cached icon, e.g. after apps change on disk.
    func removeAll() {
        cache.removeAllObjects()
    }

    func isCached(_ url: URL) -> Bool {
        cache.object(forKey: url.path as NSString) != nil
    }

    /// Built-in settings panes are empty stubs that Finder shows as blank documents,
    /// so they borrow the System Settings icon. Panes that ship their own icon keep it.
    static func iconSource(for url: URL) -> URL {
        guard url.pathExtension == "prefPane" else { return url }
        let info = Bundle(url: url)?.infoDictionary
        if info?["NSPrefPaneIconFile"] != nil || info?["CFBundleIconFile"] != nil {
            return url
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") ?? url
    }
}
