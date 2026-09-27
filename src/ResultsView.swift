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

/// Draws results as a single horizontal row. Text is measured once per list/font change
/// (`layoutItems`), so `draw` only paints the items intersecting the dirty rect.
class ResultsView: NSView {
    let rectFillPadding: CGFloat = 5
    let itemSpacing: CGFloat = 10
    private let appearanceManager = AppearanceManager.shared
    private(set) var resultsList: [ListItem] = []

    /// Items actually drawn: the list, or a placeholder when empty.
    private var drawList: [ListItem] = []
    /// Measured text size and x offset for each entry of `drawList`.
    private var itemSizes: [NSSize] = []
    private var itemOffsets: [CGFloat] = []

    var selectedRect: NSRect {
        return highlightRect(at: selectedIndexValue)
    }

    var selectedIndexValue: Int = 0
    var selectedIndex: Int {
        get {
            return selectedIndexValue
        }
        set {
            if newValue < 0 || newValue >= resultsList.count || newValue == selectedIndexValue {
                return
            }

            let previous = selectedIndexValue
            selectedIndexValue = newValue
            setNeedsDisplay(highlightRect(at: previous))
            setNeedsDisplay(highlightRect(at: newValue))
            scrollToVisible(selectedRect)
        }
    }

    var list: [ListItem] {
        get {
            return resultsList
        }
        set {
            selectedIndexValue = 0
            resultsList = newValue
            layoutItems()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layoutItems()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        layoutItems()
    }

    func selectedItem() -> ListItem? {
        if selectedIndexValue < 0 || selectedIndexValue >= resultsList.count {
            return nil
        } else {
            return resultsList[selectedIndexValue]
        }
    }

    func clear() {
        list = []
    }

    /// Re-measures every item; call when the font changes.
    func invalidateLayout() {
        layoutItems()
    }

    private func layoutItems() {
        drawList = resultsList.isEmpty ? [ListItem(name: "No results", data: nil)] : resultsList
        let attributes: [NSAttributedString.Key: Any] = [.font: appearanceManager.currentFont]

        itemSizes.removeAll(keepingCapacity: true)
        itemOffsets.removeAll(keepingCapacity: true)
        itemSizes.reserveCapacity(drawList.count)
        itemOffsets.reserveCapacity(drawList.count)

        var textX = rectFillPadding
        for item in drawList {
            let size = (item.name as NSString).size(withAttributes: attributes)
            itemSizes.append(size)
            itemOffsets.append(textX)
            textX += itemSpacing + size.width
        }

        // Trailing padding mirrors the leading one instead of leaving a full item gap.
        setFrameSize(NSSize(width: textX - itemSpacing + rectFillPadding, height: frame.height))
        needsDisplay = true
        scrollToVisible(selectedRect)
    }

    private func textRect(at index: Int) -> NSRect {
        let size = itemSizes[index]
        return NSRect(x: itemOffsets[index], y: (bounds.height - size.height) / 2,
                      width: size.width, height: size.height)
    }

    private func highlightRect(at index: Int) -> NSRect {
        guard index >= 0, index < itemSizes.count else {
            return NSRect()
        }
        return textRect(at: index).insetBy(dx: -rectFillPadding, dy: -rectFillPadding)
    }

    /// Indices of the items whose highlight rect overlaps `rect` (touching edges don't count,
    /// as neighbouring highlights share an edge). Offsets are sorted, so the first candidate
    /// is found by binary search and the scan stops past the right edge.
    func visibleRange(in rect: NSRect) -> Range<Int> {
        var low = 0
        var high = itemSizes.count
        while low < high {
            let mid = (low + high) / 2
            if highlightRect(at: mid).maxX <= rect.minX {
                low = mid + 1
            } else {
                high = mid
            }
        }

        var end = low
        while end < itemSizes.count && highlightRect(at: end).minX < rect.maxX {
            end += 1
        }
        return low ..< end
    }

    override func draw(_ dirtyRect: NSRect) {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: appearanceManager.currentFont,
            .foregroundColor: appearanceManager.resultsTextColor
        ]

        for i in visibleRange(in: dirtyRect) {
            if selectedIndexValue == i {
                appearanceManager.selectionHighlightColor.setFill()
                highlightRect(at: i).fill()
            }

            (drawList[i].name as NSString).draw(in: textRect(at: i), withAttributes: textAttributes)
        }
    }
}
