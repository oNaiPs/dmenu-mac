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
        ScreenContext(mouseLocation: NSEvent.mouseLocation, activeWindowFrame: frontmostWindowFrame())
    }

    /// Frame of the frontmost app's top window. The bar's panel never activates the app,
    /// so the frontmost app is still the one the user was in. Window bounds and owner PIDs
    /// are readable without Screen Recording permission.
    private static func frontmostWindowFrame() -> NSRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let primary = NSScreen.screens.first,
              let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
              ) as? [[String: Any]] else { return nil }

        for info in windows {
            guard info[kCGWindowOwnerPID as String] as? pid_t == pid,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }
            // Quartz measures from the top-left of the primary display.
            return NSRect(x: rect.minX, y: primary.frame.maxY - rect.maxY,
                          width: rect.width, height: rect.height)
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
