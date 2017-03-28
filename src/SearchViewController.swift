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
    
    @IBOutlet private var searchText: NSTextField!
    @IBOutlet private var resultsText: ResultsView!
    var settingsWindow = NSWindow()
    var hotkey: DDHotKey?
    
    var appDirDict = [String: Bool]()
    var appList = [NSURL]()
    var appNameList = [String]()
    
    struct Shortcut {
        let keycode: UInt16
        let modifierFlags: UInt
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchText.delegate = self;
        
        let applicationDir = NSSearchPathForDirectoriesInDomains(
            .ApplicationDirectory, .LocalDomainMask, true)[0];
        
        // appName to dir recursivity key/valye dict
        appDirDict[applicationDir] = true
        appDirDict["/System/Library/CoreServices/"] = false
        
        initFileWatch(Array(appDirDict.keys))
        updateAppList()
        
        NSUserDefaults.standardUserDefaults().registerDefaults([
            //cmd+Space is the default shortcut
            kDefaultsGlobalShortcutKeycode: kVK_Space,
            kDefaultsGlobalShortcutModifiedFlags: NSEventModifierFlags.Command.rawValue
            ])
        
        configureGlobalShortcut()
    }
    
    func initFileWatch(dirs: [String]) {
        let allocator: CFAllocator? = kCFAllocatorDefault
        
        typealias FSEventStreamCallback = @convention(c) (ConstFSEventStreamRef, UnsafeMutablePointer<Void>, Int, UnsafeMutablePointer<Void>, UnsafePointer<FSEventStreamEventFlags>, UnsafePointer<FSEventStreamEventId>) -> Void
        let callback: FSEventStreamCallback = {
            (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) -> Void in
            let mySelf = Unmanaged<SearchViewController>.fromOpaque(
                COpaquePointer(clientCallBackInfo)).takeUnretainedValue()

            mySelf.updateAppList()
        }
        
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutablePointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil)
        
        let sinceWhen: FSEventStreamEventId = UInt64(kFSEventStreamEventIdSinceNow)
        let latency: CFTimeInterval = 1.0
        let flags: FSEventStreamCreateFlags = UInt32(kFSEventStreamCreateFlagNone)
        
        let eventStream = FSEventStreamCreate(
            allocator,
            callback,
            &context,
            dirs,
            sinceWhen,
            latency,
            flags
        )
        
        FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
        FSEventStreamStart(eventStream)
    }
    
    func updateAppList() {
        appList.removeAll()
        appNameList.removeAll()
        for dir in appDirDict.keys {
            appList.appendContentsOf(
                getAppList(
                    NSURL(fileURLWithPath: dir, isDirectory: true),
                    recursive: appDirDict[dir]!))
        }
        
        for app in appList {
            let appName = (app.URLByDeletingPathExtension?.lastPathComponent)
            appNameList.append(appName!)
        }
    }
    
    func getGlobalShortcut() -> Shortcut {
        let keycode =  NSUserDefaults.standardUserDefaults()
            .integerForKey(kDefaultsGlobalShortcutKeycode)
        let modifierFlags = NSUserDefaults.standardUserDefaults()
            .integerForKey(kDefaultsGlobalShortcutModifiedFlags)
        return Shortcut(keycode: UInt16(keycode), modifierFlags: UInt(modifierFlags))
    }
    
    func configureGlobalShortcut() {
        let globalShortcut = getGlobalShortcut()

        if hotkey != nil {
            DDHotKeyCenter.sharedHotKeyCenter()
                .unregisterHotKey(hotkey)
        }
        
        hotkey = DDHotKeyCenter.sharedHotKeyCenter()
            .registerHotKeyWithKeyCode(globalShortcut.keycode,
                modifierFlags: globalShortcut.modifierFlags,
                target: self, action: #selector(resumeApp), object: nil)

        if hotkey == nil {
            print("Could not register global shortcut.")
        }
    }
    
    func resumeApp() {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        view.window?.collectionBehavior = NSWindowCollectionBehavior.CanJoinAllSpaces
        view.window?.orderFrontRegardless()
        
        let controller = view.window as! SearchWindow;
        controller.updatePosition();
    }
    
    func getAppList(appDir: NSURL, recursive: Bool = true) -> [NSURL] {
        var list = [NSURL]()
        let fileManager = NSFileManager.defaultManager()
        
        do {
            let subs = try fileManager.contentsOfDirectoryAtPath(appDir.path!)
            
            for sub in subs {
                let dir = appDir.URLByAppendingPathComponent(sub)!
                
                if dir.pathExtension == "app" {
                    list.append(dir);
                } else if dir.hasDirectoryPath && recursive {
                    list.appendContentsOf(self.getAppList(dir))
                }
            }
        } catch {
            print(error)
        }
        return list
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        let list = self.getFuzzyList()
        
        if !list.isEmpty {
            self.resultsText.list = list
        } else {
            self.resultsText.clear()
        }
    }
    
    func control(control: NSControl, textView: NSTextView, doCommandBySelector commandSelector: Selector) -> Bool {
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
                NSWorkspace.sharedWorkspace().launchApplication(app.path!)
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
        NSApplication.sharedApplication().hide(nil)
    }
    
    func getStartingBy(text: String) -> [NSURL] {
        //todo turn this into a regex
        return appList.sort({
            //make it sorted
            let appName1 = ($0.URLByDeletingPathExtension!.lastPathComponent?.lowercaseString)!
            let appName2 = ($1.URLByDeletingPathExtension!.lastPathComponent?.lowercaseString)!
            
            return appName1.localizedCaseInsensitiveCompare(appName2) == NSComparisonResult.OrderedAscending
        }).filter({
            let appName = ($0.URLByDeletingPathExtension!.lastPathComponent?.lowercaseString)!
            return appName.hasPrefix(text.lowercaseString) ||
                appName.containsString(" " + text.lowercaseString)
        })
    }
    
    func getFuzzyList() -> [NSURL] {
        var scoreDict = [NSURL: Double]()
        
        for app in appList {
            let appName = (app.URLByDeletingPathExtension?.lastPathComponent)
            
            let score = FuzzySearch.score(
                originalString: appName!, stringToMatch: self.searchText.stringValue)
            
            if score > 0 {
                scoreDict[app] = score
            }
        }
        
        let resultsList = scoreDict
            .sort({$0.1 > $1.1}).map({$0.0})
        return resultsList
    }
    
    @IBAction func openSettings(sender: AnyObject) {
        let sb = NSStoryboard(name: "Settings", bundle: NSBundle.mainBundle())
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

