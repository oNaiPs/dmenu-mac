//
//  SettingsWindow.swift
//  dmenu-mac
//
//  Created by Jose Pereira on 2/23/16.
//  Copyright © 2016 Jose Pereira. All rights reserved.
//

import Cocoa

public protocol SettingsViewControllerDelegate {
    func onSettingsCanceled()
    func onSettingsApplied()
}

class SettingsViewController: NSViewController {

    @IBOutlet var hotkeyTextField: DDHotKeyTextField!
    var delegate: SettingsViewControllerDelegate?
    
    override func viewDidLoad() {
        let keycode =  NSUserDefaults.standardUserDefaults()
            .integerForKey(kDefaultsGlobalShortcutKeycode)
        let modifierFlags = NSUserDefaults.standardUserDefaults()
            .integerForKey(kDefaultsGlobalShortcutModifiedFlags)

        hotkeyTextField.hotKey = DDHotKey(
            keyCode: UInt16(keycode),
            modifierFlags: UInt(modifierFlags),
            task: nil)
    }
    
    @IBAction func applySettings(sender: AnyObject) {
        NSUserDefaults.standardUserDefaults().setInteger(
            Int(hotkeyTextField.hotKey.keyCode), forKey: kDefaultsGlobalShortcutKeycode)
        NSUserDefaults.standardUserDefaults().setInteger(
            Int(hotkeyTextField.hotKey.modifierFlags), forKey: kDefaultsGlobalShortcutModifiedFlags)
        
        delegate?.onSettingsApplied()
    }
    
    @IBAction func cancelSettings(sender: AnyObject) {
        delegate?.onSettingsCanceled()
    }
}