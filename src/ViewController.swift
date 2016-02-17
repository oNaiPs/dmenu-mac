//
//  Created by Jose Pereira on 2/14/16.
//  Copyright © 2016 fidalgo.io. All rights reserved.
//

import Foundation
import Cocoa

class ViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet private var searchText: NSTextField!
    @IBOutlet private var resultsText: ResultsView!
    
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
            
            for sub in subs {
                let dir = appDir.URLByAppendingPathComponent(sub)
                
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
        if commandSelector == "moveLeft:" {
            self.resultsText.selectedAppIndex--
            return true
        } else if commandSelector == "moveRight:" {
            self.resultsText.selectedAppIndex++
            return true
        } else if commandSelector == "insertTab:" {
            let list = getStartingBy(searchText.stringValue)
            if !list.isEmpty {
                self.resultsText.list = list
            } else {
                self.resultsText.clear()
            }
            
            return true
        } else if commandSelector == "insertNewline:" {
            //open current selected app
            let app = resultsText.selectedApp
            NSWorkspace.sharedWorkspace().launchApplication(app.path!)
            
            self.clearFields()
            return true
        } else if commandSelector == "cancelOperation:" {
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
}

