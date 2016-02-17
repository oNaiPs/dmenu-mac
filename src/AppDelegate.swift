//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Cocoa
import Carbon

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var controllerWindow: NSWindowController? = nil
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        let res = DDHotKeyCenter.sharedHotKeyCenter()
            .registerHotKeyWithKeyCode(UInt16(kVK_Space),
                modifierFlags: NSEventModifierFlags.CommandKeyMask.rawValue,
                target: self, action: Selector("resumeApp"), object: nil)
        if res == nil {
            print("Could not register global shortcut.")
        }
        
        let sb = NSStoryboard(name: "Main", bundle: NSBundle.mainBundle())
        controllerWindow = sb.instantiateInitialController() as? NSWindowController
        controllerWindow?.window?.orderFrontRegardless()
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
    }
    
    func resumeApp() {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        controllerWindow?.window?.orderFrontRegardless()
    }
}

