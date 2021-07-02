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

class ResultsView: NSView {
    @IBOutlet fileprivate var scrollView: NSScrollView!

    let rectFillPadding: CGFloat = 5
    var resultsList = [URL]()

    var dirtyWidth: Bool = false

    var selectedAppIndexValue: Int = 0
    var selectedAppIndex: Int {
        get {
            return selectedAppIndexValue
        }
        set {
            if newValue < 0 || newValue >= resultsList.count {
                return
            }

            selectedAppIndexValue = newValue
            needsDisplay = true
        }
    }
    var selectedAppRect: NSRect = NSRect()

    var list: [URL] {
        get {
            return resultsList
        }
        set {
            selectedAppIndexValue = 0
            resultsList = newValue
            needsDisplay = true
        }
    }

    func selectedApp() -> URL? {
        if selectedAppIndexValue < 0 || selectedAppIndexValue >= resultsList.count {
            return nil
        } else {
            return resultsList[selectedAppIndexValue]
        }
    }

    func clear() {
        resultsList.removeAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        var textX = CGFloat(rectFillPadding)
        for i in 0 ..< list.count {
            let appName = (resultsList[i].deletingPathExtension().lastPathComponent) as NSString
            let size = appName.size(withAttributes: [NSAttributedString.Key: Any]())
            let textY = (frame.height - size.height) / 2

            if selectedAppIndexValue == i {
                selectedAppRect = NSRect(
                    x: textX - rectFillPadding,
                    y: textY - rectFillPadding,
                    width: size.width + rectFillPadding * 2,
                    height: size.height + rectFillPadding * 2)
                NSColor.selectedTextBackgroundColor.setFill()
                __NSRectFill(selectedAppRect)
            }

            appName.draw(in: NSRect(
                            x: textX,
                            y: textY,
                            width: size.width,
                            height: size.height), withAttributes: [
                                NSAttributedString.Key.foregroundColor: NSColor.textColor
                            ])

            textX += 10 + size.width
        }
        if dirtyWidth {
            frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: textX, height: frame.height)
            dirtyWidth = false
            scrollView.contentView.scrollToVisible(selectedAppRect)
        }
    }

    func updateWidth() {
        dirtyWidth = true
    }
}
