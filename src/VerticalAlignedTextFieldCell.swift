//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//
//  Textfield with vertically centered text

import Cocoa

class VerticalAlignedTextFieldCell: NSTextFieldCell {
    var editingOrSelecting: Bool = false
    
    override func drawingRect(forBounds theRect: NSRect) -> NSRect {
        var newRect = super.drawingRect(forBounds: theRect)
        if !editingOrSelecting {
            let textSize = self.cellSize(forBounds: theRect)
            let heightDelta = newRect.size.height - textSize.height
            if heightDelta > 0 {
                newRect.size.height -= heightDelta;
                newRect.origin.y += (heightDelta / 2);
            }
        }
        return newRect
    }
    
    override func select(withFrame aRect: NSRect, in controlView: NSView, editor textObj: NSText, delegate anObject: Any?, start selStart: Int, length selLength: Int) {
        let aRect = self.drawingRect(forBounds: aRect)
        editingOrSelecting = true;
        super.select(withFrame: aRect,
            in: controlView,
            editor: textObj,
            delegate: anObject,
            start: selStart,
            length: selLength)
        
        editingOrSelecting = false;
    }
    
    override func edit(withFrame aRect: NSRect, in controlView: NSView, editor textObj: NSText, delegate anObject: Any?, event theEvent: NSEvent?) {
        let aRect = self.drawingRect(forBounds: aRect)
        editingOrSelecting = true;
        self.edit(withFrame: aRect,
            in: controlView,
            editor: textObj,
            delegate: anObject,
            event: theEvent)
        editingOrSelecting = false;
    }
}
