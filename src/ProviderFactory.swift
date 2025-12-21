/*
 * Copyright (c) 2025 Jose Pereira <onaips@gmail.com>.
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
 * Factory class for creating appropriate ListProvider instances
 * Implements dependency injection pattern
 */
class ProviderFactory {
    /**
     * Creates appropriate provider based on stdin content
     * - Parameter stdinContent: Content from stdin
     * - Returns: PipeListProvider if stdin has content, otherwise AppListProvider
     */
    func createProvider(stdinContent: String) -> ListProvider {
        if stdinContent.count > 0 {
            return PipeListProvider(str: stdinContent)
        } else {
            return AppListProvider()
        }
    }
}
