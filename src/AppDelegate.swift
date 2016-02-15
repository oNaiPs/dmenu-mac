//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 Jose Pereira. All rights reserved.
//

import Cocoa
import Carbon

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(aNotification: NSNotification) {
         let res = DDHotKeyCenter.sharedHotKeyCenter()
            .registerHotKeyWithKeyCode(UInt16(kVK_Space),
                modifierFlags: NSEventModifierFlags.CommandKeyMask.rawValue,
                target: self, action: Selector("resumeApp"), object: nil)
        if (res == nil) {
            print("Could not register global shortcut.")
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
    }

    func resumeApp() {
        //not sure if this is the most performant, it's taking couple ms to open the app in my machine.
        NSWorkspace.sharedWorkspace().launchApplication(NSBundle.mainBundle().executablePath!)
    }
}

