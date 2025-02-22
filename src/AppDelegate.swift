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
import Carbon
import LaunchAtLogin
import Settings
import KeyboardShortcuts

extension Settings.PaneIdentifier {
    static let general = Self("general")
}

// import legacy settings if they existed
let kLegacyKc = "kDefaultsGlobalShortcutKeycode"
let kLegacyMf = "kDefaultsGlobalShortcutModifiedFlags"

extension KeyboardShortcuts.Name {
    static let activateSearch = Self("activateSearchGlobalShortcut", default: .init(
        (UserDefaults.standard.object(forKey: kLegacyKc) != nil) ?
            KeyboardShortcuts.Key(rawValue: UserDefaults.standard.integer(forKey: kLegacyKc)):
                .space,
        modifiers: (UserDefaults.standard.object(forKey: kLegacyKc) != nil) ?
        NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: kLegacyMf))) :
            [.command]))
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    @IBOutlet var controllerWindow: NSWindowController?

    private var statusItem: NSStatusItem!
    private var startAtLaunch: NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "d"
        }
        setupMenus()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    func setupMenus() {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open", action: #selector(resumeApp), keyEquivalent: "")
        menu.addItem(open)

        let settings = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(settings)

        menu.addItem(NSMenuItem.separator())
         startAtLaunch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        startAtLaunch.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(startAtLaunch)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))

        statusItem.menu = menu
    }

    @objc func resumeApp() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: Bundle.main)
        // swiftlint:disable force_cast
        let mainPageController = storyboard.instantiateController(
            withIdentifier: "SearchViewController") as! SearchViewController
        // swiftlint:enable force_cast
        mainPageController.resumeApp()
    }

    @objc func openSettings() {
        settingsWindowController.show()
    }

    @objc func toggleLaunchAtLogin() {
        let enabled = !LaunchAtLogin.isEnabled
        LaunchAtLogin.isEnabled = enabled
        startAtLaunch.state = enabled ? .on : .off
    }

    private lazy var settings: [SettingsPane] = [
        GeneralSettingsViewController()
    ]

    private lazy var settingsWindowController = SettingsWindowController(
        panes: settings,
        style: .segmentedControl,
        animated: true,
        hidesToolbarForSingleItem: true
    )
}
