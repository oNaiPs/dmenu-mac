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

import Foundation

class InputField: NSTextField {
    override func becomeFirstResponder() -> Bool {
        let responderStatus =  super.becomeFirstResponder()

        if let fieldEditor = self.window?.fieldEditor(true, for: self) as? NSTextView {
            fieldEditor.selectedTextAttributes = [
                // Make selection transparent
                NSAttributedString.Key.backgroundColor: NSColor.clear
            ]
            // Make blinking cursos transparent
            fieldEditor.insertionPointColor = NSColor.clear
        }

        return responderStatus
    }
}
