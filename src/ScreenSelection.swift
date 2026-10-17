/*
 * Copyright (c) 2026 Jose Pereira <onaips@gmail.com>.
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

/// Which display the bar appears on.
enum ScreenSelection: String, CaseIterable {
    case activeWindow
    case mouse
    case primary

    var title: String {
        switch self {
        case .activeWindow: return "Screen with active window"
        case .mouse: return "Screen with mouse pointer"
        case .primary: return "Primary screen"
        }
    }
}

/// The parts of a display the picker needs, so tests can use plain values instead of `NSScreen`.
protocol ScreenDescribing {
    var frame: NSRect { get }
    var visibleFrame: NSRect { get }
}

extension NSScreen: ScreenDescribing {}

/// Where the pointer and the frontmost window are, in Cocoa (bottom-left origin) coordinates.
struct ScreenContext {
    var mouseLocation: NSPoint
    var activeWindowFrame: NSRect?

    static func current() -> ScreenContext {
        var windowFrame: NSRect?
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
           let primary = NSScreen.screens.first,
           let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
           ) as? [[String: Any]] {
            windowFrame = frontmostWindowFrame(in: windows, pid: pid, primaryHeight: primary.frame.maxY,
                                               screenFrames: NSScreen.screens.map(\.frame))
        }
        return ScreenContext(mouseLocation: NSEvent.mouseLocation, activeWindowFrame: windowFrame)
    }

    /// Smaller windows are treated as helpers rather than something the user is looking at.
    static let minimumWindowSize: CGFloat = 50

    /**
     * Frame of the frontmost app's top real window, from `CGWindowListCopyWindowInfo` output
     * (front to back). The bar's panel never activates the app, so the frontmost app is still
     * the one the user was in. Window bounds and owner PIDs are readable without Screen
     * Recording permission. Skips invisible, tiny and off-screen helper windows, which
     * Electron and Chromium apps keep around.
     */
    static func frontmostWindowFrame(in windows: [[String: Any]], pid: pid_t,
                                     primaryHeight: CGFloat, screenFrames: [NSRect]) -> NSRect? {
        for info in windows {
            guard info[kCGWindowOwnerPID as String] as? pid_t == pid,
                  info[kCGWindowLayer as String] as? Int == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  rect.width >= minimumWindowSize, rect.height >= minimumWindowSize else { continue }
            // Quartz measures down from the top-left of the primary display.
            let frame = NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
            if screenFrames.contains(where: { $0.intersects(frame) }) {
                return frame
            }
        }
        return nil
    }
}

enum ScreenPicker {
    /**
     * The screen to show the bar on. A valid `monitor` index wins over `selection`;
     * when nothing matches, falls back to `fallback` (normally `NSScreen.main`), then the first screen.
     */
    static func pick<Screen: ScreenDescribing>(
        from screens: [Screen],
        selection: ScreenSelection,
        monitor: Int? = nil,
        context: ScreenContext,
        fallback: Screen? = nil
    ) -> Screen? {
        if let monitor, screens.indices.contains(monitor) {
            return screens[monitor]
        }

        let picked: Screen?
        switch selection {
        case .primary:
            picked = screens.first
        case .mouse:
            // `NSMouseInRect` treats the top edge as inside, matching how Cocoa reports the pointer.
            picked = screens.first { NSMouseInRect(context.mouseLocation, $0.frame, false) }
        case .activeWindow:
            picked = context.activeWindowFrame.flatMap { screen(mostlyContaining: $0, in: screens) }
        }
        return picked ?? fallback ?? screens.first
    }

    private static func screen<Screen: ScreenDescribing>(mostlyContaining rect: NSRect,
                                                         in screens: [Screen]) -> Screen? {
        let overlaps = screens.map { screen -> (Screen, CGFloat) in
            let common = screen.frame.intersection(rect)
            return (screen, common.isNull ? 0 : common.width * common.height)
        }
        guard let best = overlaps.max(by: { $0.1 < $1.1 }), best.1 > 0 else { return nil }
        return best.0
    }
}
