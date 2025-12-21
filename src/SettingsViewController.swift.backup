/*
 * Copyright (c) 2016 Jose Pereira <onaips@gmail.com>.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import Cocoa

public protocol SettingsViewControllerDelegate: AnyObject {
    func onSettingsCanceled()
    func onSettingsApplied()
}

class SettingsViewController: NSViewController {

    @IBOutlet var hotkeyTextField: DDHotKeyTextField!
    weak var delegate: SettingsViewControllerDelegate?

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
