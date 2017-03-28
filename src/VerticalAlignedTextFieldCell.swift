//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//
//  Textfield with vertically centered text

import Cocoa

class VerticalAlignedTextFieldCell: NSTextFieldCell {
    var editingOrSelecting: Bool = false
    
    override func drawingRectForBounds(theRect: NSRect) -> NSRect {
        var newRect = super.drawingRectForBounds(theRect)
        if !editingOrSelecting {
            let textSize = self.cellSizeForBounds(theRect)
            let heightDelta = newRect.size.height - textSize.height
            if heightDelta > 0 {
                newRect.size.height -= heightDelta;
                newRect.origin.y += (heightDelta / 2);
            }
        }
        return newRect
    }
    
    override func selectWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, start selStart: Int, length selLength: Int) {
        let aRect = self.drawingRectForBounds(aRect)
        editingOrSelecting = true;
        super.selectWithFrame(aRect,
            inView: controlView,
            editor: textObj,
            delegate: anObject,
            start: selStart,
            length: selLength)
        
        editingOrSelecting = false;
    }
    
    override func editWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, event theEvent: NSEvent?) {
        let aRect = self.drawingRectForBounds(aRect)
        editingOrSelecting = true;
        self.editWithFrame(aRect,
            inView: controlView,
            editor: textObj,
            delegate: anObject,
            event: theEvent)
        editingOrSelecting = false;
    }
}