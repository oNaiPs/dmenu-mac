//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa

class SearchWindow: NSPanel {
    
    override func awakeFromNib() {
        self.hasShadow = false
        updatePosition()
    }
    
    /**
     * Updates search window position.
     */
    func updatePosition() {
        //TODO allow to reappear on different screen depending on current focus
        let screenSize = NSScreen.mainScreen()
        
        let frame = NSRect(x: 0, y: (screenSize?.frame.height)! - self.frame.height,
            width: (screenSize?.frame.width)!,
            height: self.frame.height)
        
        setFrame(frame, display: false)
    }
    
    override var canBecomeKeyWindow: Bool {
        return true
    }
    
    override var canBecomeMainWindow: Bool {
        return true
    }
}