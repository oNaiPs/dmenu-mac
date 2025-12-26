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
    var listProvider: ListProvider?
    var searchService: SearchService?
    var promptValue = ""
    private let appearanceManager = AppearanceManager.shared

    deinit {
        DistributedNotificationCenter.default.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        searchText.delegate = self

        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(interfaceModeChanged),
            name: .AppleInterfaceThemeChangedNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceSettingsChanged),
            name: .appearanceSettingsChanged,
            object: nil
        )

        // Use dependency injection if provider already set, otherwise create default
        if listProvider == nil {
            let factory = ProviderFactory()
            let stdinStr = ReadStdin.read()
            listProvider = factory.createProvider(stdinContent: stdinStr)
        }

        // Create search service
        if let provider = listProvider {
            searchService = SearchService(provider: provider)
        }

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let options = DmenuMac.parseOrExit()
            if options.prompt != nil {
                promptValue = options.prompt!
            }
        }

        clearFields()
        resumeApp()
    }

    @objc func interfaceModeChanged(sender: NSNotification) {
        updateColors()
    }

    @objc func appearanceSettingsChanged(sender: NSNotification) {
        updateColors()
        updateFonts()
    }

    func updateColors() {
        guard let window = NSApp.windows.first else { return }

        window.isOpaque = false
        window.backgroundColor = appearanceManager.windowBackgroundColor
            .withAlphaComponent(appearanceManager.windowOpacity)
        searchText.textColor = appearanceManager.searchTextColor

        resultsText.needsDisplay = true
    }

    func updateFonts() {
        searchText.font = appearanceManager.currentFont

        // Update field editor if searchText is currently being edited
        if let fieldEditor = searchText.window?.fieldEditor(false, for: searchText) as? NSTextView {
            fieldEditor.font = appearanceManager.currentFont
        }

        // Update placeholder text font
        let placeholderText: String
        if let attributedPlaceholder = searchText.placeholderAttributedString {
            placeholderText = attributedPlaceholder.string
        } else if let plainPlaceholder = searchText.placeholderString {
            placeholderText = plainPlaceholder
        } else {
            placeholderText = ""
        }

        if !placeholderText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: appearanceManager.currentFont
            ]
            searchText.placeholderAttributedString = NSAttributedString(
                string: placeholderText,
                attributes: attributes
            )
        }

        resultsText.needsDisplay = true
    }

    @objc func resumeApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        view.window?.orderFrontRegardless()

        if let controller = view.window as? SearchWindow {
            controller.updatePosition()
        }

        updateColors()
        updateFonts()
    }

    func controlTextDidChange(_ obj: Notification) {
        if searchText.stringValue == "" {
            clearFields()
            return
        }

        // Use SearchService for fuzzy search
        guard let searchService = searchService else {
            return
        }

        let results = searchService.search(query: searchText.stringValue)

        if !results.isEmpty {
            self.resultsText.list = results
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
        // Use SearchService for consistent sorting (search with empty query returns sorted list)
        self.resultsText.list = searchService?.search(query: "") ?? []
    }

    func closeApp() {
        clearFields()
        if promptValue == "" {
            NSApplication.shared.hide(nil)
        }
    }
}
