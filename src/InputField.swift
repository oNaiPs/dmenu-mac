/*
 * Copyright (c) 2016 Jose Pereira <onaips@gmail.com>.
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

class InputField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let responderStatus =  super.becomeFirstResponder()

        if let fieldEditor = self.window?.fieldEditor(true, for: self) as? NSTextView {
            fieldEditor.selectedTextAttributes = [
                NSAttributedString.Key.backgroundColor: AppearanceManager.shared.selectionHighlightColor
            ]
            // Make blinking cursos transparent
            fieldEditor.insertionPointColor = NSColor.clear
        }

        return responderStatus
    }

    // The app has no Edit menu, so standard editing shortcuts must be routed manually.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let action: Selector?

        switch (modifiers, event.charactersIgnoringModifiers) {
        case (.command, "v"): action = #selector(NSText.paste(_:))
        case (.command, "c"): action = #selector(NSText.copy(_:))
        case (.command, "x"): action = #selector(NSText.cut(_:))
        case (.command, "a"): action = #selector(NSText.selectAll(_:))
        case (.command, "z"): action = Selector(("undo:"))
        case ([.command, .shift], "z"), ([.command, .shift], "Z"): action = Selector(("redo:"))
        default: action = nil
        }

        if let action = action, currentEditor() != nil,
           NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
