/*
 * Copyright (c) 2023 Jose Pereira <onaips@gmail.com>.
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
import Settings

final class AppearanceSettingsViewController: NSViewController, SettingsPane {
    let paneIdentifier = Settings.PaneIdentifier.appearance
    let paneTitle = "Appearance"
    let toolbarItemIcon = NSImage(
        systemSymbolName: "paintbrush",
        accessibilityDescription: "Appearance settings"
    )!

    // MARK: - IBOutlets
    @IBOutlet weak var searchTextColorWell: NSColorWell!
    @IBOutlet weak var resultsTextColorWell: NSColorWell!
    @IBOutlet weak var selectionHighlightColorWell: NSColorWell!
    @IBOutlet weak var windowBackgroundColorWell: NSColorWell!
    @IBOutlet weak var opacitySlider: NSSlider!
    @IBOutlet weak var opacityLabel: NSTextField!
    @IBOutlet weak var fontNameLabel: NSTextField!
    @IBOutlet weak var fontSizeLabel: NSTextField!
    @IBOutlet weak var fontSizeStepper: NSStepper!

    private let appearanceManager = AppearanceManager.shared

    override var nibName: NSNib.Name? { "AppearanceSettingsViewController" }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupColorWells()
        setupOpacitySlider()
        setupFontControls()
        loadSettings()
    }

    // MARK: - Setup Methods
    private func setupColorWells() {
        searchTextColorWell.target = self
        searchTextColorWell.action = #selector(colorChanged(_:))

        resultsTextColorWell.target = self
        resultsTextColorWell.action = #selector(colorChanged(_:))

        selectionHighlightColorWell.target = self
        selectionHighlightColorWell.action = #selector(colorChanged(_:))

        windowBackgroundColorWell.target = self
        windowBackgroundColorWell.action = #selector(colorChanged(_:))
    }

    private func setupOpacitySlider() {
        opacitySlider.minValue = 0.2
        opacitySlider.maxValue = 1.0
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged(_:))
    }

    private func setupFontControls() {
        fontSizeStepper.minValue = 8.0
        fontSizeStepper.maxValue = 72.0
        fontSizeStepper.increment = 1.0
        fontSizeStepper.target = self
        fontSizeStepper.action = #selector(fontSizeChanged(_:))
    }

    private func loadSettings() {
        searchTextColorWell.color = appearanceManager.searchTextColor
        resultsTextColorWell.color = appearanceManager.resultsTextColor
        selectionHighlightColorWell.color = appearanceManager.selectionHighlightColor
        windowBackgroundColorWell.color = appearanceManager.windowBackgroundColor

        opacitySlider.doubleValue = Double(appearanceManager.windowOpacity)
        updateOpacityLabel()

        fontSizeStepper.doubleValue = Double(appearanceManager.fontSize)
        updateFontLabels()
    }

    // MARK: - Actions
    @objc private func colorChanged(_ sender: NSColorWell) {
        if sender === searchTextColorWell {
            appearanceManager.searchTextColor = sender.color
        } else if sender === resultsTextColorWell {
            appearanceManager.resultsTextColor = sender.color
        } else if sender === selectionHighlightColorWell {
            appearanceManager.selectionHighlightColor = sender.color
        } else if sender === windowBackgroundColorWell {
            appearanceManager.windowBackgroundColor = sender.color
        }
        notifySettingsChanged()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        appearanceManager.windowOpacity = CGFloat(sender.doubleValue)
        updateOpacityLabel()
        notifySettingsChanged()
    }

    @objc private func fontSizeChanged(_ sender: NSStepper) {
        appearanceManager.fontSize = CGFloat(sender.doubleValue)
        updateFontLabels()
        notifySettingsChanged()
    }

    @IBAction func selectFont(_ sender: Any) {
        let fontPanel = NSFontPanel.shared
        fontPanel.setPanelFont(appearanceManager.currentFont, isMultiple: false)
        NSFontManager.shared.target = self
        fontPanel.orderFront(nil)
    }

    @objc func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager else { return }
        let selectedFont = fontManager.convert(appearanceManager.currentFont)

        appearanceManager.fontName = selectedFont.fontName
        appearanceManager.fontSize = selectedFont.pointSize
        fontSizeStepper.doubleValue = Double(selectedFont.pointSize)

        updateFontLabels()
        notifySettingsChanged()
    }

    @IBAction func resetToDefaults(_ sender: Any) {
        appearanceManager.resetToDefaults()
        loadSettings()
        notifySettingsChanged()
    }

    // MARK: - UI Updates
    private func updateOpacityLabel() {
        let percentage = Int(appearanceManager.windowOpacity * 100)
        opacityLabel.stringValue = "\(percentage)%"
    }

    private func updateFontLabels() {
        let font = appearanceManager.currentFont
        fontNameLabel.stringValue = font.displayName ?? font.fontName
        fontSizeLabel.stringValue = "\(Int(appearanceManager.fontSize)) pt"
    }

    private func notifySettingsChanged() {
        NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
    }
}
