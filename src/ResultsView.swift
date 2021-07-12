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
    var resultsList: [ListItem] = []

    var dirtyWidth: Bool = false
    var selectedRect = NSRect()

    var selectedIndexValue: Int = 0
    var selectedIndex: Int {
        get {
            return selectedIndexValue
        }
        set {
            if newValue < 0 || newValue >= resultsList.count {
                return
            }

            selectedIndexValue = newValue
            needsDisplay = true
        }
    }

    var list: [ListItem] {
        get {
            return resultsList
        }
        set {
            selectedIndexValue = 0
            resultsList = newValue
            needsDisplay = true
        }
    }

    func selectedItem() -> ListItem? {
        if selectedIndexValue < 0 || selectedIndexValue >= resultsList.count {
            return nil
        } else {
            return resultsList[selectedIndexValue]
        }
    }

    func clear() {
        resultsList.removeAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        var textX = CGFloat(rectFillPadding)
        let drawList = list.count > 0 ? list : [ListItem(name: "No results", data: nil)]

        for i in 0 ..< drawList.count {
            let item = (drawList[i].name) as NSString
            let size = item.size(withAttributes: [NSAttributedString.Key: Any]())
            let textY = (frame.height - size.height) / 2

            if selectedIndexValue == i {
                selectedRect = NSRect(
                    x: textX - rectFillPadding,
                    y: textY - rectFillPadding,
                    width: size.width + rectFillPadding * 2,
                    height: size.height + rectFillPadding * 2)
                NSColor.selectedTextBackgroundColor.setFill()
                __NSRectFill(selectedRect)
            }

            item.draw(in: NSRect(
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
            scrollView.contentView.scrollToVisible(selectedRect)
        }
    }

    func updateWidth() {
        dirtyWidth = true
    }
}
