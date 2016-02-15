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
    }
    
    override var canBecomeKeyWindow: Bool {
        return true
    }
}