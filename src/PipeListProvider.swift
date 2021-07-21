/*
 * Copyright (c) 2020 Jose Pereira <onaips@gmail.com>.
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

import Foundation

/**
 * Provide a list from a terminal pipe. When action is performed, quit app since we act like a prompt
 */
class PipeListProvider: ListProvider {
    var choices = [String]()

    init(str: String) {
        choices = str.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "\n")
    }

    func get() -> [ListItem] {
        return choices.map({ListItem(name: $0, data: nil)})
    }

    func doAction(item: ListItem) {
        print(item.name)
        NSApplication.shared.terminate(self)
    }
}
