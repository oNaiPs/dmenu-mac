//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 Jose Pereira. All rights reserved.
//

import Cocoa

class SearchWindow: NSPanel {
    
    override func awakeFromNib() {
        let screenSize = NSScreen.mainScreen()
        self.hasShadow = false
        
        let frame = NSRect(x: 0, y: (screenSize?.frame.height)! - self.frame.height,
            width: (screenSize?.frame.width)!,
            height: self.frame.height)
        
        setFrame(frame, display: false)
        //        setFrame(frame)
    }
    
    override var canBecomeKeyWindow: Bool {
        return true
    }
    
    
    override func drawLayer(layer: CALayer, inContext ctx: CGContext) {
        NSGraphicsContext.saveGraphicsState()
        
        
        NSBezierPath(roundedRect: self.frame, xRadius: 5, yRadius: 5)
        //        self.la
        NSGraphicsContext.restoreGraphicsState()
        
    }
    
    //    - (void) drawRect:(NSRect)dirtyRect{
    //    [[NSColor windowBackgroundColor] set];
    //
    //    [NSGraphicsContext saveGraphicsState];
    //    NSBezierPath *path;
    //    path = [NSBezierPath bezierPathWithRoundedRect:[self bounds] xRadius:5 yRadius:5];
    //
    //    ... // do more fancy stuff here ;)
    //
    //    [NSGraphicsContext restoreGraphicsState];
    //    }
    
}