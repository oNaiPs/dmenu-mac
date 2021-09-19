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

#import "ReadStdin.h"

#import <poll.h>

@implementation ReadStdin

+(NSString *)read {
    char buf[BUFSIZ];

    // prevent fgets from being blocked
    int flags;
    flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    flags |= O_NONBLOCK;
    fcntl(STDIN_FILENO, F_SETFL, flags);

    NSMutableString *str = [NSMutableString string];
    while (fgets(buf, sizeof(BUFSIZ), stdin) != 0) {
        [str appendString:[NSString stringWithUTF8String:buf]];
    }
    
    return str;
}

@end
