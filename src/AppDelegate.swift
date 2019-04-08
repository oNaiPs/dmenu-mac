//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa
import Carbon

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var controllerWindow: NSWindowController? = nil
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let sb = NSStoryboard(name: "Main", bundle: Bundle.main)
        controllerWindow = sb.instantiateInitialController() as? NSWindowController
        controllerWindow?.window?.backgroundColor = NSColor.windowBackgroundColor
        controllerWindow?.window?.orderFrontRegardless()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
}

