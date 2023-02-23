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
import KeyboardShortcuts

class SearchViewController: NSViewController, NSTextFieldDelegate, NSWindowDelegate {

    @IBOutlet fileprivate var searchText: InputField!
    @IBOutlet fileprivate var resultsText: ResultsView!
    var hotkey: DDHotKey?
    var listProvider: ListProvider?
    var promptValue = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        searchText.delegate = self

        KeyboardShortcuts.onKeyUp(for: .activateSearch) { [self] in
            resumeApp()
        }

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(interfaceModeChanged),
            name: .AppleInterfaceThemeChangedNotification,
            object: nil
        )

        let stdinStr = ReadStdin.read()
        if stdinStr.count > 0 {
            listProvider = PipeListProvider(str: stdinStr)
        } else {
            listProvider = AppListProvider()
        }

        let options = DmenuMac.parseOrExit()
        if options.prompt != nil {
            promptValue = options.prompt!
        }

        clearFields()
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

    @objc func resumeApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        view.window?.orderFrontRegardless()

        if let controller = view.window as? SearchWindow {
            controller.updatePosition()
        }

        updateColors()
    }

    func controlTextDidChange(_ obj: Notification) {
        if searchText.stringValue == "" {
            clearFields()
            return
        }

        // Get provider list, filter using fuzzy search, apply
        var scoreDict = [Int: Double]()

        let fuse = Fuse(threshold: 0.4)
        let pattern = fuse.createPattern(from: searchText.stringValue)

        let list = listProvider?.get() ?? []

        for (idx, item) in list.enumerated() {
            guard let result = fuse.search(pattern, in: item.name) else {
                continue
            }
            scoreDict[idx] = result.score
        }

        let sortedScoreDict = scoreDict.sorted(by: {$0.1 < $1.1}).map({list[$0.0]})
        if !sortedScoreDict.isEmpty {
            self.resultsText.list = sortedScoreDict
        } else {
            self.resultsText.clear()
        }

        self.resultsText.updateWidth()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        let movingLeft: Bool =
            commandSelector == #selector(moveLeft(_:)) ||
            commandSelector == #selector(insertBacktab(_:))
        let movingRight: Bool =
            commandSelector == #selector(moveRight(_:)) ||
            commandSelector == #selector(insertTab(_:))

        if movingLeft {
            resultsText.selectedIndex = resultsText.selectedIndex == 0 ?
                resultsText.list.count - 1 : resultsText.selectedIndex - 1
            resultsText.updateWidth()
            return true
        } else if movingRight {
            resultsText.selectedIndex = (resultsText.selectedIndex + 1) % resultsText.list.count
            resultsText.updateWidth()
            return true
        } else if commandSelector == #selector(insertNewline(_:)) {
            // open current selected app
            if let item = resultsText.selectedItem() {
                listProvider?.doAction(item: item)
                closeApp()
            }

            return true
        } else if commandSelector == #selector(cancelOperation(_:)) {
            closeApp()
            return true
        }

        return false
    }

    func clearFields() {
        self.searchText.stringValue = promptValue
        self.resultsText.list = listProvider?.get().sorted(by: {$0.name < $1.name}) ?? []
    }

    func closeApp() {
        clearFields()
        if promptValue == "" {
            NSApplication.shared.hide(nil)
        }
    }
}
