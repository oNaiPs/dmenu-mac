//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 Jose Pereira. All rights reserved.
//

import Foundation
import Cocoa

class ViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet private var searchText: NSTextField!
    @IBOutlet private var resultsText: NSTextField!
    
    var appList = [NSURL]()
    var appNameList = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchText.delegate = self;
        
        // appName to dir recursivity key/valye dict
        var appDirDict = [String: Bool]()
        
        appDirDict[NSSearchPathForDirectoriesInDomains(
            .ApplicationDirectory, .LocalDomainMask, true)[0]] = true
        appDirDict["/System/Library/CoreServices/"] = false
        
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
    
    func getAppList(appDir: NSURL, recursive: Bool = true) -> [NSURL] {
        var list = [NSURL]()
        let fileManager = NSFileManager.defaultManager()
        
        do {
            let subs = try fileManager.contentsOfDirectoryAtPath(appDir.path!)
            let totalFiles = subs.count
            
            print(totalFiles)
            for sub in subs {
                let dir = appDir.URLByAppendingPathComponent(sub)
                
                if dir.pathExtension == "app" {
                    print("APP: \(sub)");
                    list.append(dir);
                } else if (dir.hasDirectoryPath && recursive) {
                    print("DIR enter!: \(dir.absoluteString)");
                    list.appendContentsOf(self.getAppList(dir))
                } else {
                    print("NOAPP NODIR \(dir)")
                }
            }
        } catch _ {
            NSLog("ERROR")
        }
        return list
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        let list = self.getFuzzyList()
            .map {($0.URLByDeletingPathExtension?.lastPathComponent)!}
        
        self.resultsText.stringValue = (list).joinWithSeparator("  ")
    }
    
    override func controlTextDidEndEditing(obj: NSNotification) {
        let list = self.getFuzzyList()
        print(list.first?.absoluteString)
        
        if let app = list.first {
            NSWorkspace.sharedWorkspace().launchApplication(app.path!)
        }
        
        self.searchText.stringValue = ""
        self.resultsText.stringValue = ""
    }
    
    @IBAction func closeApp(sender: NSButton) {
        self.closeApp()
    }
    
    func closeApp() {
        NSApplication.sharedApplication().hide(nil)
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
}

