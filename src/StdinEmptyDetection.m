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

#import "StdinEmptyDetection.h"

#import <poll.h>

@implementation StdinEmptyDetection

+ (bool)isStdinEmpty {
    struct pollfd stdin_poll = {
        .fd = STDIN_FILENO,
        .events = POLLIN | POLLRDBAND | POLLRDNORM | POLLPRI
    };

    if (poll(&stdin_poll, 1, 0) == 1) {
        return false;
    }
    return true;
}

@end
