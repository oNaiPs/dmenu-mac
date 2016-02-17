//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa

class ResultsView: NSView {
    let rectFillPadding:CGFloat = 5
    var _list = [NSURL]()
    
    var _selectedAppIndex: Int = 0
    var selectedAppIndex: Int {
        get {
            return _selectedAppIndex
        }
        set {
            if newValue < 0 || newValue >= _list.count {
                return
            }
            
            _selectedAppIndex = newValue
            needsDisplay = true;
        }
    }
    
    var list: [NSURL] {
        get {
            return _list
        }
        set {
            _selectedAppIndex = 0
            _list = newValue;
            needsDisplay = true;
        }
    }
    
    var selectedApp: NSURL {
        get {
            return _list[_selectedAppIndex]
        }
    }
    
    func clear() {
        _list.removeAll()
        needsDisplay = true;
    }
    
    override func drawRect(dirtyRect: NSRect) {
        let textFontAttributes = [String: AnyObject]()
        
        var textX = CGFloat(rectFillPadding)
        for var i = 0; i < list.count; i++ {
            let appName = (_list[i].URLByDeletingPathExtension?.lastPathComponent)! as NSString
            let size = appName.sizeWithAttributes(textFontAttributes)
            let textY = (frame.height - size.height) / 2
            
            if _selectedAppIndex == i {
                NSColor.selectedTextBackgroundColor().setFill()
                NSRectFill(NSRect(
                    x: textX - rectFillPadding,
                    y: textY - rectFillPadding,
                    width: size.width + rectFillPadding * 2,
                    height: size.height + rectFillPadding * 2))
            }
            
            appName.drawInRect(NSRect(
                x: textX,
                y: textY,
                width: size.width,
                height: size.height), withAttributes: [String: AnyObject]())
            
            textX += 10 + size.width;
            
            //stop drawing if we passed the visible frame
            if textX > frame.width {
                break;
            }
        }
    }
}
