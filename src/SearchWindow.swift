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

/// Takes keyboard input without activating the app, so the previous app stays frontmost.
class SearchWindow: NSPanel {

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style.union(.nonactivatingPanel),
                   backing: backingStoreType, defer: flag)
    }

    override func awakeFromNib() {
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = NSWindow.CollectionBehavior.canJoinAllSpaces
        // Stay above the Dock, which otherwise covers the bar when placed on the side,
        // but below the menu bar so it isn't hidden.
        self.level = NSWindow.Level(rawValue: NSWindow.Level.dock.rawValue + 1)
        updatePosition()
    }

    /**
     * Updates search window position.
     */
    func updatePosition(_ position: WindowPosition = AppearanceManager.shared.windowPosition) {
        guard let screen = NSScreen.main else { return }

        let frame = Self.frame(for: position, in: screen.frame, height: self.frame.height)
        setFrame(frame, display: false)
    }

    /**
     * Full-width bar frame of the given height, pinned to `position` within `screenFrame`.
     */
    static func frame(for position: WindowPosition, in screenFrame: NSRect, height: CGFloat) -> NSRect {
        let originY: CGFloat
        switch position {
        case .top:
            originY = screenFrame.maxY - height
        case .bottom:
            originY = screenFrame.minY
        }

        return NSRect(x: screenFrame.minX, y: originY, width: screenFrame.width, height: height)
    }

    // The app has no main menu (LSUIElement), so handle Cmd-, here to open Settings.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "," {
            return NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: self)
        }
        return super.performKeyEquivalent(with: event)
    }

    // Replaces hidesOnDeactivate, since the app never activates.
    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return false
    }
}
