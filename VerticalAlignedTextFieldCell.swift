//
//  VerticalAlignedTextField.swift
//  dmenu-mac
//
//  Created by Jose Pereira on 2/15/16.
//  Copyright © 2016 Jose Pereira. All rights reserved.
//

import Cocoa

class VerticalAlignedTextFieldCell: NSTextFieldCell {
    
    func adjustedFrameToVerticallyCenterText(frame: NSRect) -> NSRect {
        let offset = floor((NSHeight(frame) -
            (self.font!.ascender - self.font!.descender)) / CGFloat(2))
        return NSInsetRect(frame, 0.0, offset)
    }
    
    override func editWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, event theEvent: NSEvent) {
        
        super.editWithFrame(self.adjustedFrameToVerticallyCenterText(aRect),
            inView: controlView,
            editor: textObj,
            delegate: anObject,
            event: theEvent)
    }
    
    override func selectWithFrame(aRect: NSRect, inView controlView: NSView, editor textObj: NSText, delegate anObject: AnyObject?, start selStart: Int, length selLength: Int) {
        super.selectWithFrame(self.adjustedFrameToVerticallyCenterText(aRect),
            inView: controlView,
            editor: textObj,
            delegate: anObject,
            start: selStart,
            length: selLength)
    }

    override func drawInteriorWithFrame(cellFrame: NSRect, inView controlView: NSView) {
        super.drawInteriorWithFrame(self.adjustedFrameToVerticallyCenterText(cellFrame),
            inView: controlView)
    }

}