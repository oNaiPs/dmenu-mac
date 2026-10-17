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
import Carbon

/// Asks TCC about Apple Events sent to another app.
struct SystemAutomationPermissions: AutomationPermissions {
    func status(for bundleIdentifier: String) -> AutomationStatus {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil else {
            return .notInstalled
        }
        return Self.determine(bundleIdentifier, askUserIfNeeded: false)
    }

    func requestAccess(for bundleIdentifier: String, completion: @escaping (AutomationStatus) -> Void) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            completion(.notInstalled)
            return
        }

        let ask = {
            // Blocks until the user answers the prompt.
            DispatchQueue.global(qos: .userInitiated).async {
                let status = Self.determineWaitingForLaunch(bundleIdentifier)
                DispatchQueue.main.async { completion(status) }
            }
        }

        if isRunning(bundleIdentifier) {
            ask()
            return
        }

        // TCC only answers for a running target, so start it in the background first.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.hides = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error = error {
                NSLog("Cannot launch %@ to ask for Automation access: %@",
                      bundleIdentifier, error.localizedDescription)
            }
            ask()
        }
    }

    private func isRunning(_ bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// A freshly launched app may not take Apple Events yet, so retry briefly while it starts.
    private static func determineWaitingForLaunch(_ bundleIdentifier: String) -> AutomationStatus {
        var status = determine(bundleIdentifier, askUserIfNeeded: true)
        var attempts = 0
        while status == .notRunning && attempts < 20 {
            Thread.sleep(forTimeInterval: 0.25)
            status = determine(bundleIdentifier, askUserIfNeeded: true)
            attempts += 1
        }
        return status
    }

    private static func determine(_ bundleIdentifier: String, askUserIfNeeded: Bool) -> AutomationStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        guard let address = target.aeDesc else {
            return .failed(OSStatus(paramErr))
        }
        // Consent is per app pair, so any real event works; wildcards don't always bring up the prompt.
        let osStatus = AEDeterminePermissionToAutomateTarget(
            address, AEEventClass(kAECoreSuite), AEEventID(kAEGetData), askUserIfNeeded)
        return AutomationStatus(osStatus: osStatus)
    }
}
