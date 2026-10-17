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

/// The parts of NSApplication that DockPresence drives, so tests can swap them out.
protocol ActivationPolicyApplying: AnyObject {
    func applyActivationPolicy(_ policy: NSApplication.ActivationPolicy)
    func bringToFront()
    /// Runs `work` on a later main run loop turn.
    func onNextTurn(_ work: @escaping () -> Void)
    /// Hands focus back to another app.
    func returnFocus(to other: NSRunningApplication)
}

extension NSApplication: ActivationPolicyApplying {
    func applyActivationPolicy(_ policy: NSApplication.ActivationPolicy) {
        setActivationPolicy(policy)
        if policy == .regular {
            // Switching at runtime can leave a generic icon in the Dock until it is set explicitly.
            applicationIconImage = NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        }
    }

    func bringToFront() {
        // On macOS 14+ the cooperative activate() is refused here (seen on macOS 26 from the status
        // menu and from ⌘, in the launcher): the window stays behind and never becomes key.
        // The older call still brings the app forward.
        activate(ignoringOtherApps: true)
    }

    func onNextTurn(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    func returnFocus(to other: NSRunningApplication) {
        other.activate(options: [])
    }
}

/**
 * dmenu-mac is a menu bar (accessory) app without a Dock icon, so a regular window that slips
 * behind others can't be found again. While such a window is open the app becomes a regular
 * app (Dock and ⌘Tab), and goes back to accessory, returning focus, once the last one closes.
 */
final class DockPresence {
    static let shared = DockPresence(app: NSApp)

    private let app: ActivationPolicyApplying
    private let previousAppProvider: () -> NSRunningApplication?
    private var windows: [NSWindow] = []
    private var observers: [ObjectIdentifier: NSObjectProtocol] = [:]
    /// The app to hand focus back to: the last other app that was active while windows are open.
    private(set) var previousApp: NSRunningApplication?
    private let workspaceCenter: NotificationCenter
    private var activationObserver: NSObjectProtocol?

    init(app: ActivationPolicyApplying,
         previousAppProvider: @escaping () -> NSRunningApplication? = DockPresence.frontmostOtherApp,
         workspaceCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.app = app
        self.previousAppProvider = previousAppProvider
        self.workspaceCenter = workspaceCenter
    }

    static func frontmostOtherApp() -> NSRunningApplication? {
        let front = NSWorkspace.shared.frontmostApplication
        return isOtherApp(front) ? front : nil
    }

    private static func isOtherApp(_ other: NSRunningApplication?) -> Bool {
        guard let other else { return false }
        return other.processIdentifier != ProcessInfo.processInfo.processIdentifier
    }

    var isActive: Bool { !windows.isEmpty }

    /// Shows the app in the Dock until `window` closes, and makes `window` the key window.
    func show(_ window: NSWindow) {
        if windows.isEmpty {
            previousApp = previousAppProvider()
            // The user may switch apps while the window is open; return to the latest one.
            activationObserver = workspaceCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil) { [weak self] note in
                    let activated = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                    if Self.isOtherApp(activated) {
                        self?.previousApp = activated
                    }
            }
            app.applyActivationPolicy(.regular)
        }
        if !windows.contains(where: { $0 === window }) {
            windows.append(window)
            observers[ObjectIdentifier(window)] = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: nil) { [weak self] note in
                    (note.object as? NSWindow).map { self?.windowClosed($0) }
            }
        }
        bringForward(window)
        // A new activation policy only takes effect on a later turn, and activating before
        // that can be ignored, so ask again once it has.
        app.onNextTurn { [weak self, weak window] in
            guard let self, let window, self.windows.contains(where: { $0 === window }) else { return }
            self.bringForward(window)
        }
    }

    /// Clicking the Dock icon brings back the tracked window; false when there is none.
    func reopen() -> Bool {
        guard let window = windows.last else { return false }
        bringForward(window)
        return true
    }

    private func bringForward(_ window: NSWindow) {
        app.bringToFront()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func windowClosed(_ window: NSWindow) {
        guard let index = windows.firstIndex(where: { $0 === window }) else { return }
        windows.remove(at: index)
        if let observer = observers.removeValue(forKey: ObjectIdentifier(window)) {
            NotificationCenter.default.removeObserver(observer)
        }
        guard windows.isEmpty else { return }
        if let activationObserver {
            workspaceCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        app.applyActivationPolicy(.accessory)
        if let previousApp {
            app.returnFocus(to: previousApp)
        }
        previousApp = nil
    }
}
