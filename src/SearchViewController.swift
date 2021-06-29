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

import Carbon
import Cocoa
import Fuse
import FileWatcher

let kDefaultsGlobalShortcutKeycode = "kDefaultsGlobalShortcutKeycode"
let kDefaultsGlobalShortcutModifiedFlags = "kDefaultsGlobalShortcutModifiedFlags"

class SearchViewController: NSViewController, NSTextFieldDelegate,
    NSWindowDelegate, SettingsViewControllerDelegate {
    
    @IBOutlet fileprivate var searchText: NSTextField!
    @IBOutlet fileprivate var resultsText: ResultsView!
    var settingsWindow = NSWindow()
    var hotkey: DDHotKey?
    
    var appDirDict = [String: Bool]()
    var appList = [URL]()
    
    struct Shortcut {
        let keycode: UInt16
        let modifierFlags: UInt
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchText.delegate = self;
        
        let applicationDir = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .localDomainMask, true)[0];
        
        // Catalina moved default applications under a different mask.
        let systemApplicationDir = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .systemDomainMask, true)[0];
        
        // appName to dir recursivity key/valye dict
        appDirDict[applicationDir] = true
        appDirDict[systemApplicationDir] = true
        appDirDict["/System/Library/CoreServices/"] = false
        
        initFileWatch(Array(appDirDict.keys))
        updateAppList()
        
        UserDefaults.standard.register(defaults: [
            //cmd+Space is the default shortcut
            kDefaultsGlobalShortcutKeycode: kVK_Space,
            kDefaultsGlobalShortcutModifiedFlags: NSEvent.ModifierFlags.command.rawValue
            ])
        
        configureGlobalShortcut()
        
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(interfaceModeChanged),
            name: .AppleInterfaceThemeChangedNotification,
            object: nil
        )
        
        resumeApp()
    }
    
    @objc func interfaceModeChanged(sender: NSNotification) {
        updateColors()
    }
    
    func updateColors() {
        guard let window = NSApp.windows.first else { return }
        
        window.isOpaque = false
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.6)
        searchText.textColor = NSColor.textColor
    }
	
    func initFileWatch(_ dirs: [String]) {
        let filewatcher = FileWatcher(dirs);
        filewatcher.callback = {event in
            self.updateAppList()
        }
        filewatcher.start()
    }
    
    func updateAppList() {
        var newAppList = [URL]()
        appDirDict.keys.forEach{ path in
            let urlPath = URL(fileURLWithPath: path, isDirectory: true)
            let list = getAppList(urlPath, recursive: appDirDict[path]!)
            newAppList.append(contentsOf: list)
        }
        appList = newAppList
    }
    
    func getAppList(_ appDir: URL, recursive: Bool = true) -> [URL] {
        var list = [URL]()
        let fileManager = FileManager.default
        
        do {
            let subs = try fileManager.contentsOfDirectory(atPath: appDir.path)
            
            for sub in subs {
                let dir = appDir.appendingPathComponent(sub)
                
                if dir.pathExtension == "app" {
                    list.append(dir);
                } else if dir.hasDirectoryPath && recursive {
                    list.append(contentsOf: self.getAppList(dir))
                }
            }
        } catch {
            print(error)
        }
        return list
    }
    
    func getGlobalShortcut() -> Shortcut {
        let keycode =  UserDefaults.standard
            .integer(forKey: kDefaultsGlobalShortcutKeycode)
        let modifierFlags = UserDefaults.standard
            .integer(forKey: kDefaultsGlobalShortcutModifiedFlags)
        return Shortcut(keycode: UInt16(keycode), modifierFlags: UInt(modifierFlags))
    }
    
    func configureGlobalShortcut() {
        let globalShortcut = getGlobalShortcut()

        if hotkey != nil {
            DDHotKeyCenter.shared().unregisterHotKey(hotkey)
        }
        
        hotkey = DDHotKeyCenter.shared()
            .registerHotKey(
                withKeyCode: globalShortcut.keycode,
                modifierFlags: globalShortcut.modifierFlags,
                target: self, action: #selector(resumeApp), object: nil)

        if hotkey == nil {
            print("Could not register global shortcut.")
        }
    }
    
    @objc func resumeApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        view.window?.orderFrontRegardless()
        
        if let controller = view.window as? SearchWindow {
            controller.updatePosition();
        }
        
        updateColors()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        let list = self.getFuzzyList()
        
        if !list.isEmpty {
            self.resultsText.list = list
        } else {
            self.resultsText.clear()
        }
        
        self.resultsText.updateWidth()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(moveLeft(_:)) {
            if resultsText.selectedAppIndex > 0 {
                resultsText.selectedAppIndex -= 1
            }
            resultsText.updateWidth()
            return true
        } else if commandSelector == #selector(moveRight(_:)) {
            if resultsText.selectedAppIndex < resultsText.list.count - 1 {
                resultsText.selectedAppIndex += 1
            }
            resultsText.updateWidth()
            return true
        } else if commandSelector == #selector(insertTab(_:)) {
            let list = getStartingBy(searchText.stringValue)
            if !list.isEmpty {
                resultsText.list = list
            } else {
                resultsText.clear()
            }
            
            return true
        } else if commandSelector == #selector(insertNewline(_:)) {
            //open current selected app
            if let app = resultsText.selectedApp {
                DispatchQueue.main.async {
                    NSWorkspace.shared.launchApplication(app.path)
                }
            }
            
            closeApp()
            return true
        } else if commandSelector == #selector(cancelOperation(_:)) {
            closeApp()
            return true
        }
        
        return false
    }
    
    func clearFields() {
        self.searchText.stringValue = ""
        self.resultsText.clear()
    }
    
    func closeApp() {
        clearFields()
        NSApplication.shared.hide(nil)
    }
    
    func getStartingBy(_ text: String) -> [URL] {
        //todo turn this into a regex
        return appList.sorted(by: {
            //make it sorted
            let appName1 = (($0 as NSURL).deletingPathExtension!.lastPathComponent.lowercased())
            let appName2 = (($1 as NSURL).deletingPathExtension!.lastPathComponent.lowercased())
            
            return appName1.localizedCaseInsensitiveCompare(appName2) == ComparisonResult.orderedAscending
        }).filter({
            let appName = (($0 as NSURL).deletingPathExtension!.lastPathComponent.lowercased())
            return appName.hasPrefix(text.lowercased()) ||
                appName.contains(" " + text.lowercased())
        })
    }
    
    func getFuzzyList() -> [URL] {
        var scoreDict = [URL: Double]()
        let fuse = Fuse(threshold: 0.4)

        for app in appList {
            let appName = (app.deletingPathExtension().lastPathComponent)
            
            guard let result = fuse.search(searchText.stringValue, in: appName) else {
                continue
            }
            
            scoreDict[app] = result.score
        }
        
        return scoreDict.sorted(by: {$0.1 > $1.1}).reversed().map({$0.0})
    }

    @IBAction func openSettings(_ sender: AnyObject) {
        let sb = NSStoryboard(name: "Settings", bundle: Bundle.main)
        let settingsView = sb.instantiateInitialController() as? SettingsViewController
        settingsView?.delegate = self
        
        settingsWindow.contentViewController = settingsView
        weak var wSettingsWindow = settingsWindow
        
        view.window?.beginSheet(settingsWindow,
                                completionHandler: { (response) -> Void in
                                    wSettingsWindow?.contentViewController = nil
        })
    }

    
    func onSettingsApplied() {
        view.window?.endSheet(settingsWindow)

        //reconfigure global shortcuts if changed
        configureGlobalShortcut()
    }
    
    func onSettingsCanceled() {
        view.window?.endSheet(settingsWindow)
    }
}

