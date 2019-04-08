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
        let keycode =  UserDefaults.standard
            .integer(forKey: kDefaultsGlobalShortcutKeycode)
        let modifierFlags = UserDefaults.standard
            .integer(forKey: kDefaultsGlobalShortcutModifiedFlags)
        
        hotkeyTextField.hotKey = DDHotKey(
            keyCode: UInt16(keycode),
            modifierFlags: UInt(modifierFlags),
            task: nil)
    }
    
    @IBAction func applySettings(_ sender: AnyObject) {
        UserDefaults.standard.set(
            Int(hotkeyTextField.hotKey.keyCode), forKey: kDefaultsGlobalShortcutKeycode)
        UserDefaults.standard.set(
            Int(hotkeyTextField.hotKey.modifierFlags), forKey: kDefaultsGlobalShortcutModifiedFlags)
        
        delegate?.onSettingsApplied()
    }
    
    @IBAction func cancelSettings(_ sender: AnyObject) {
        delegate?.onSettingsCanceled()
    }
}
