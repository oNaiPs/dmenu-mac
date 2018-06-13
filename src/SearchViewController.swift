//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Carbon
import Cocoa

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
    var appNameList = [String]()
    
    struct Shortcut {
        let keycode: UInt16
        let modifierFlags: UInt
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchText.delegate = self;
        
        let applicationDir = NSSearchPathForDirectoriesInDomains(
            .applicationDirectory, .localDomainMask, true)[0];
        
        // appName to dir recursivity key/valye dict
        appDirDict[applicationDir] = true
        appDirDict["/System/Library/CoreServices/"] = false
        
        initFileWatch(Array(appDirDict.keys))
        updateAppList()
        
        UserDefaults.standard.register(defaults: [
            //cmd+Space is the default shortcut
            kDefaultsGlobalShortcutKeycode: kVK_Space,
            kDefaultsGlobalShortcutModifiedFlags: NSEventModifierFlags.command.rawValue
            ])
    
        configureGlobalShortcut()
    }
    
    private let eventCallback: FSEventStreamCallback = { (stream: OpaquePointer, contextInfo: Optional<UnsafeMutableRawPointer>, numEvents: Int, eventPaths: UnsafeMutableRawPointer, eventFlags: UnsafePointer<UInt32>, eventIds: UnsafePointer<UInt64>) in
        let mySelf: SearchViewController = unsafeBitCast(contextInfo, to: SearchViewController.self)
        mySelf.updateAppList()
    }
	
    func initFileWatch(_ dirs: [String]) {
        let allocator: CFAllocator? = kCFAllocatorDefault
        
        typealias FSEventStreamCallback = @convention(c) (ConstFSEventStreamRef, UnsafeMutableRawPointer, Int, UnsafeMutableRawPointer, UnsafePointer<FSEventStreamEventFlags>, UnsafePointer<FSEventStreamEventId>) -> Void
		
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil)
        
        let sinceWhen: FSEventStreamEventId = UInt64(kFSEventStreamEventIdSinceNow)
        let latency: CFTimeInterval = 1.0
        let flags: FSEventStreamCreateFlags = UInt32(kFSEventStreamCreateFlagNone)
		
		let eventStream: FSEventStreamRef! = FSEventStreamCreate(
            allocator,
            eventCallback,
            &context,
            dirs as CFArray,
            sinceWhen,
            latency,
            flags
        )
        
        FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(eventStream)
    }
    
    func updateAppList() {
        appList.removeAll()
        appNameList.removeAll()
        for dir in appDirDict.keys {
            appList.append(
                contentsOf: getAppList(
                    URL(fileURLWithPath: dir, isDirectory: true),
                    recursive: appDirDict[dir]!))
        }
        
        for app in appList {
            let appName = (app.deletingPathExtension().lastPathComponent)
            appNameList.append(appName)
        }
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
            DDHotKeyCenter.shared()
                .unregisterHotKey(hotkey)
        }
        
        hotkey = DDHotKeyCenter.shared()
            .registerHotKey(withKeyCode: globalShortcut.keycode,
                modifierFlags: globalShortcut.modifierFlags,
                target: self, action: #selector(resumeApp), object: nil)

        if hotkey == nil {
            print("Could not register global shortcut.")
        }
    }
    
    func resumeApp() {
        NSApplication.shared().activate(ignoringOtherApps: true)
        view.window?.collectionBehavior = NSWindowCollectionBehavior.canJoinAllSpaces
        view.window?.orderFrontRegardless()
        
        guard let osxMode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") else {
            // Default to normal color
            return
        }
        
        if (osxMode == "Dark") {
            // Set Dark Mode
            if self.view.layer != nil {
                let color : CGColor = CGColor(red: 0.035, green: 0.035, blue: 0.035, alpha: 0.9)
                self.view.layer?.backgroundColor = color
                searchText.textColor = NSColor.white
                resultsText._textColor = NSColor.white
            }
        } else {
            // Set light mode
            if self.view.layer != nil {
                let color : CGColor = CGColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.9)
                self.view.layer?.backgroundColor = color
                searchText.textColor = NSColor.black
                resultsText._textColor = NSColor.black
            }
        }
        
        let controller = view.window as! SearchWindow;
        controller.updatePosition();
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
    
    override func controlTextDidChange(_ obj: Notification) {
        let list = self.getFuzzyList()
        
        if !list.isEmpty {
            self.resultsText.list = list
        } else {
            self.resultsText.clear()
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(moveLeft(_:)) {
            self.resultsText.selectedAppIndex -= 1
            return true
        } else if commandSelector == #selector(moveRight(_:)) {
            self.resultsText.selectedAppIndex += 1
            return true
        } else if commandSelector == #selector(insertTab(_:)) {
            let list = getStartingBy(searchText.stringValue)
            if !list.isEmpty {
                self.resultsText.list = list
            } else {
                self.resultsText.clear()
            }
            
            return true
        } else if commandSelector == #selector(insertNewline(_:)) {
            //open current selected app
            if let app = resultsText.selectedApp {
                NSWorkspace.shared().launchApplication(app.path)
            }
            
            self.clearFields()
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
        NSApplication.shared().hide(nil)
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
        
        for app in appList {
            let appName = (app.deletingPathExtension().lastPathComponent)
            
            let score = FuzzySearch.score(
                originalString: appName, stringToMatch: self.searchText.stringValue)
            
            if score > 0 {
                scoreDict[app] = score
            }
        }
        
        let resultsList = scoreDict
            .sorted(by: {$0.1 > $1.1}).map({$0.0})
        return resultsList
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

