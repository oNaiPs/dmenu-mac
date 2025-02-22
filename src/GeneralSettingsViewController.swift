/*
 * Copyright (c) 2023 Jose Pereira <onaips@gmail.com>.
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
import Settings
import KeyboardShortcuts

final class GeneralSettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.general
    let paneTitle = "General"
    let toolbarItemIcon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General settings")!

    @IBOutlet weak var customView: NSView?

    override var nibName: NSNib.Name? { "GeneralSettingsViewController" }

    override func loadView() {
        super.loadView()

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .activateSearch)
        recorder.frame = CGRect(x: 0, y: 0, width: 150, height: 25)
        customView?.addSubview(recorder)

    }
}
