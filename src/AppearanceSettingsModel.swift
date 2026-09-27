/*
 * Copyright (c) 2023 Jose Pereira <onaips@gmail.com>.
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
import SwiftUI

/// Bridges `AppearanceManager` to SwiftUI: publishes changes and notifies the search window.
final class AppearanceSettingsModel: NSObject, ObservableObject {
    static let opacityRange: ClosedRange<Double> = 0.2...1.0
    static let fontSizeRange: ClosedRange<Double> = 8...72

    private let manager: AppearanceManager

    init(manager: AppearanceManager = .shared) {
        self.manager = manager
        super.init()
    }

    deinit {
        // `NSFontManager.target` is unowned; never leave it pointing at a freed model.
        if NSFontManager.shared.target === self {
            NSFontManager.shared.target = nil
        }
    }

    // MARK: - Window

    var windowPosition: WindowPosition {
        get { manager.windowPosition }
        set { update { manager.windowPosition = newValue } }
    }

    var windowOpacity: Double {
        get { Double(manager.windowOpacity) }
        set { update { manager.windowOpacity = CGFloat(newValue) } }
    }

    var opacityText: String {
        "\(Int((windowOpacity * 100).rounded()))%"
    }

    // MARK: - Colors

    var searchTextColor: Color {
        get { Color(nsColor: manager.searchTextColor) }
        set { update { manager.searchTextColor = Self.storableColor(newValue) } }
    }

    var resultsTextColor: Color {
        get { Color(nsColor: manager.resultsTextColor) }
        set { update { manager.resultsTextColor = Self.storableColor(newValue) } }
    }

    var selectionHighlightColor: Color {
        get { Color(nsColor: manager.selectionHighlightColor) }
        set { update { manager.selectionHighlightColor = Self.storableColor(newValue) } }
    }

    var windowBackgroundColor: Color {
        get { Color(nsColor: manager.windowBackgroundColor) }
        set { update { manager.windowBackgroundColor = Self.storableColor(newValue) } }
    }

    // MARK: - Font

    var fontSize: Double {
        get { Double(manager.fontSize) }
        set { update { manager.fontSize = CGFloat(newValue) } }
    }

    var fontSizeText: String {
        "\(Int(fontSize)) pt"
    }

    var fontDisplayName: String {
        let font = manager.currentFont
        return font.displayName ?? font.fontName
    }

    func chooseFont() {
        let fontPanel = NSFontPanel.shared
        fontPanel.setPanelFont(manager.currentFont, isMultiple: false)
        NSFontManager.shared.target = self
        fontPanel.orderFront(nil)
    }

    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let font = fontManager.convert(manager.currentFont)
        update {
            manager.fontName = font.fontName
            manager.fontSize = font.pointSize
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        update { manager.resetToDefaults() }
    }

    // MARK: - Helpers

    private func update(_ change: () -> Void) {
        objectWillChange.send()
        change()
        NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
    }

    /// `NSColor(Color)` can wrap a dynamic provider that `NSKeyedArchiver` refuses to encode,
    /// so resolve it to a plain sRGB color before it reaches `UserDefaults`.
    private static func storableColor(_ color: Color) -> NSColor {
        let nsColor = NSColor(color)
        return nsColor.usingColorSpace(.sRGB) ?? nsColor
    }
}
