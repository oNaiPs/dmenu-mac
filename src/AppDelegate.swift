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
    static let appearance = Self("appearance")
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

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    @IBOutlet var controllerWindow: NSWindowController?

    private(set) var statusItem: NSStatusItem!
    private(set) var startAtLaunch: NSMenuItem!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.magnifyingglass", accessibilityDescription: "dmenu-mac")
            button.image?.isTemplate = true
        }
        setupMenus()
        setupKeyboardShortcut()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    // Opening the app again (Finder, Launchpad, Spotlight) shows the launcher, so it stays
    // reachable even when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        resumeApp()
        return false
    }

    // The login item can also be changed in System Settings > General > Login Items.
    func menuNeedsUpdate(_ menu: NSMenu) {
        startAtLaunch.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .activateSearch) { [weak self] in
            self?.resumeApp()
        }
    }

    func setupMenus() {
        let menu = NSMenu()
        menu.delegate = self

        let open = NSMenuItem(title: "Open", action: #selector(resumeApp), keyEquivalent: "")
        menu.addItem(open)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settings)

        menu.addItem(NSMenuItem.separator())
        startAtLaunch = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        startAtLaunch.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(startAtLaunch)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit dmenu-mac",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    /// Reused on every hotkey press; a new controller would re-read stdin and rescan the app folders.
    var searchViewController: SearchViewController? {
        NSApp.windows.lazy.compactMap { $0.contentViewController as? SearchViewController }.first
    }

    @objc func resumeApp() {
        searchViewController?.resumeApp()
    }

    @objc func openSettings() {
        settingsWindowController.show()
    }

    @objc func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
        startAtLaunch.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    private lazy var settings: [SettingsPane] = [
        GeneralSettingsView.pane(),
        AppearanceSettingsView.pane()
    ]

    private lazy var settingsWindowController: SettingsWindowController = {
        let controller = SettingsWindowController(
            panes: settings,
            style: .toolbarItems,
            animated: true,
            hidesToolbarForSingleItem: false
        )

        // Configure window appearance
        if let window = controller.window {
            window.styleMask.remove(.resizable)
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }

        return controller
    }()
}
