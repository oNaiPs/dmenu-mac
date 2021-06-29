//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa

class SearchWindow: NSWindow {
    
    override func awakeFromNib() {
        self.hasShadow = false
        self.collectionBehavior = NSWindow.CollectionBehavior.canJoinAllSpaces
        updatePosition()
    }
    
    /**
     * Updates search window position.
     */
    func updatePosition() {
        guard let screen = NSScreen.main else { return }
        
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.frame.minY + screen.frame.height - self.frame.height,
            width: screen.frame.width,
            height: self.frame.height)
        
        setFrame(frame, display: false)
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}
