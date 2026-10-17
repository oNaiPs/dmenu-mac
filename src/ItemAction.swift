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

/// What to do with the selected item, picked by the modifier held with Enter.
enum ItemAction: Equatable {
    /// Enter
    case open
    /// ⌘ Enter
    case reveal
    /// ⌥ Enter
    case copyPath
    /// ⌃ Enter
    case openNewInstance

    /// Shift is not mapped here: Shift Enter runs the typed text instead.
    init(modifiers: NSEvent.ModifierFlags) {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) {
            self = .reveal
        } else if flags.contains(.option) {
            self = .copyPath
        } else if flags.contains(.control) {
            self = .openNewInstance
        } else {
            self = .open
        }
    }

    static let returnKeyCodes: Set<UInt16> = [36, 76] // Return, keypad Enter

    /// Whether a field editor command means "submit". Modified Returns arrive as other commands:
    /// ⌥ as insertNewlineIgnoringFieldEditor, ⌃ as insertLineBreak, and ⌘ (unbound) as noop.
    static func isSubmit(_ selector: Selector, event: NSEvent?) -> Bool {
        if selector == #selector(NSResponder.insertNewline(_:)) {
            return true
        }
        let returnLike: [Selector] = [
            #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)),
            #selector(NSResponder.insertLineBreak(_:)),
            Selector(("noop:"))
        ]
        // Check the key too: ⌃O also sends insertNewlineIgnoringFieldEditor.
        guard returnLike.contains(selector), let event = event, event.type == .keyDown else {
            return false
        }
        return returnKeyCodes.contains(event.keyCode)
    }
}

/// Performs the alternate actions on files: apps, panes, programs from $PATH.
struct FileActions {
    var reveal: (URL) -> Void = { url in
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    var openNewInstance: (URL) -> Void = { url in
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error = error {
                NSLog("Cannot open new instance of %@: %@", url.path, error.localizedDescription)
            }
        }
    }
    var pasteboard: NSPasteboard = .general

    /// Returns false for .open so the caller does its usual action.
    @discardableResult
    func perform(_ action: ItemAction, on url: URL) -> Bool {
        switch action {
        case .open:
            return false
        case .reveal:
            DispatchQueue.main.async { reveal(url) }
        case .copyPath:
            pasteboard.clearContents()
            pasteboard.setString(url.path, forType: .string)
        case .openNewInstance:
            DispatchQueue.main.async { openNewInstance(url) }
        }
        return true
    }
}
