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
    var exitOnClose = false
    var allowCustomInput = true
    /// Set from the command line; takes precedence over the Appearance setting.
    var windowPositionOverride: WindowPosition?
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
            // reading blocks until EOF, so never wait on the test host's stdin
            let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            let stdinStr = isTesting ? "" : ReadStdin.read()
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
            exitOnClose = DmenuMac.shouldExitOnClose(flag: options.exit)
            allowCustomInput = !options.noCustom
            if options.bottom {
                windowPositionOverride = .bottom
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
        updatePosition()
    }

    var windowPosition: WindowPosition {
        windowPositionOverride ?? appearanceManager.windowPosition
    }

    func updatePosition() {
        (view.window as? SearchWindow)?.updatePosition(windowPosition)
    }

    func updateColors() {
        guard let window = NSApp.windows.first else { return }

        window.isOpaque = false
        window.backgroundColor = appearanceManager.windowBackgroundColor
            .withAlphaComponent(appearanceManager.windowOpacity)
        searchText.textColor = appearanceManager.searchTextColor

        // Update field editor if searchText is currently being edited
        if let fieldEditor = searchText.window?.fieldEditor(false, for: searchText) as? NSTextView {
            fieldEditor.textColor = appearanceManager.searchTextColor
        }

        updatePlaceholder()
        resultsText.needsDisplay = true
    }

    func updateFonts() {
        searchText.font = appearanceManager.currentFont

        // Update field editor if searchText is currently being edited
        if let fieldEditor = searchText.window?.fieldEditor(false, for: searchText) as? NSTextView {
            fieldEditor.font = appearanceManager.currentFont
        }

        updatePlaceholder()
        resultsText.needsDisplay = true
    }

    private func updatePlaceholder() {
        let placeholderText = searchText.placeholderAttributedString?.string ??
            searchText.placeholderString ?? ""
        guard !placeholderText.isEmpty else { return }

        searchText.placeholderAttributedString = NSAttributedString(
            string: placeholderText,
            attributes: [
                .font: appearanceManager.currentFont,
                .foregroundColor: appearanceManager.searchTextColor.withAlphaComponent(0.5)
            ]
        )
    }

    @objc func resumeApp() {
        updatePosition()
        updateColors()
        updateFonts()

        view.window?.makeKeyAndOrderFront(nil)
        view.window?.makeFirstResponder(searchText)
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

        if (movingLeft || movingRight) && resultsText.list.isEmpty {
            return true
        } else if movingLeft {
            resultsText.selectedIndex = resultsText.selectedIndex == 0 ?
                resultsText.list.count - 1 : resultsText.selectedIndex - 1
            resultsText.updateWidth()
            return true
        } else if movingRight {
            resultsText.selectedIndex = (resultsText.selectedIndex + 1) % resultsText.list.count
            resultsText.updateWidth()
            return true
        } else if commandSelector == #selector(insertNewline(_:)) {
            let shiftPressed = NSApp.currentEvent?.modifierFlags.contains(.shift) ?? false
            submit(preferTypedInput: shiftPressed)
            return true
        } else if commandSelector == #selector(cancelOperation(_:)) {
            listProvider?.cancel()
            closeApp()
            return true
        }

        return false
    }

    /// Acts on the selected item, falling back to the typed text when nothing matches.
    /// With preferTypedInput (Shift+Enter) the typed text wins even if there are matches.
    /// With --no-custom only list items are accepted.
    func submit(preferTypedInput: Bool) {
        if !(preferTypedInput && allowCustomInput), let item = resultsText.selectedItem() {
            listProvider?.doAction(item: item)
        } else if allowCustomInput, let input = typedInput() {
            listProvider?.doAction(input: input)
        } else {
            return
        }
        closeApp()
    }

    private func typedInput() -> String? {
        let text = searchText.stringValue
        // The prompt is shown as the field's text until the user types something.
        if text.trimmingCharacters(in: .whitespaces).isEmpty || (!promptValue.isEmpty && text == promptValue) {
            return nil
        }
        return text
    }

    func clearFields() {
        self.searchText.stringValue = promptValue
        // Use SearchService for consistent sorting (search with empty query returns sorted list)
        self.resultsText.list = searchService?.search(query: "") ?? []
    }

    func closeApp() {
        clearFields()
        if exitOnClose {
            // Queued after the provider's async action so the app launch happens first
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        } else if promptValue == "" {
            view.window?.orderOut(nil)
        }
    }
}
