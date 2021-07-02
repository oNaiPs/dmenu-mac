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

class VerticalAlignedTextFieldCell: NSTextFieldCell {
    var editingOrSelecting: Bool = false

    override func drawingRect(forBounds theRect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: theRect)
        if !editingOrSelecting {
            let textSize = self.cellSize(forBounds: theRect)
            let heightDelta = newRect.size.height - textSize.height
            if heightDelta > 0 {
                newRect.size.height -= heightDelta
                newRect.origin.y += (heightDelta / 2)
            }
        }
        return newRect
    }

    override func select(withFrame aRect: NSRect, in controlView: NSView,
                         editor textObj: NSText, delegate anObject: Any?,
                         start selStart: Int, length selLength: Int) {
        let aRect = self.drawingRect(forBounds: aRect)

        editingOrSelecting = true
        super.select(withFrame: aRect,
                     in: controlView,
                     editor: textObj,
                     delegate: anObject,
                     start: selStart,
                     length: selLength)

        editingOrSelecting = false
    }

    override func edit(withFrame aRect: NSRect, in controlView: NSView,
                       editor textObj: NSText, delegate anObject: Any?,
                       event theEvent: NSEvent?) {
        let aRect = self.drawingRect(forBounds: aRect)
        editingOrSelecting = true
        self.edit(withFrame: aRect,
                  in: controlView,
                  editor: textObj,
                  delegate: anObject,
                  event: theEvent)
        editingOrSelecting = false
    }
}
