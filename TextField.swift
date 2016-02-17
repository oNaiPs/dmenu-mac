//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa

class TextField: NSTextField {
    
    override func becomeFirstResponder() -> Bool {
        let res = super.becomeFirstResponder()
        if res {
            let editor = self.currentEditor() as! NSTextView
            if (editor.respondsToSelector(Selector("setInsertionPointColor:"))) {
                editor.insertionPointColor = self.backgroundColor!
            }
        }
        return res
    }
}