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

protocol ListProvider {
    // Returns list of items
    func get() -> [ListItem]

    // Performs action on a selected item
    func doAction(item: ListItem)

    // Performs action on free text typed by the user
    func doAction(input: String)

    // Called when the user dismisses the list without selecting anything
    func cancel()
}

extension ListProvider {
    func doAction(input: String) {}
    func cancel() {}
}

struct ListItem {
    var name: String
    var data: Any?
}
