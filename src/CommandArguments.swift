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

import ArgumentParser
import Darwin

struct DmenuMac: ParsableArguments {
    @Option(name: .shortAndLong, help: "Show a prompt instead of the search input.")
    var prompt: String?

    @Flag(inversion: .prefixedNo, help: ArgumentHelp(
        "Exit after a selection instead of staying in the background.",
        discussion: "Defaults to exiting when started from a shell, staying when opened as an app."))
    var exit: Bool?

    @Flag(name: .customLong("no-custom"), help: ArgumentHelp(
        "Only accept items from the list.",
        discussion: "By default, Enter with no matches or Shift+Enter uses the typed text."))
    var noCustom = false

    /// Opened via LaunchServices (Finder, Dock, login items, `open`) the parent is launchd;
    /// anything else (a shell, skhd, ...) is a one-shot invocation that should not linger.
    static func shouldExitOnClose(flag: Bool?, parentPID: pid_t = getppid()) -> Bool {
        return flag ?? (parentPID != 1)
    }
}
