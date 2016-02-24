//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa
import Carbon

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var controllerWindow: NSWindowController? = nil
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let sb = NSStoryboard(name: "Main", bundle: NSBundle.mainBundle())
        controllerWindow = sb.instantiateInitialController() as? NSWindowController
        controllerWindow?.window?.orderFrontRegardless()
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
    }
}

