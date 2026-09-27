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

#import <unistd.h>

@implementation ReadStdin

+(NSString *)read {
    return [self readFromFileDescriptor:STDIN_FILENO];
}

+(NSString *)readFromFileDescriptor:(int)fd {
    // only a pipe or file carries a list; never wait on an interactive terminal
    if (isatty(fd)) {
        return @"";
    }

    // block until EOF so slow producers are not dropped, and decode once so
    // multi-byte UTF-8 sequences are never split
    NSFileHandle *handle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:NO];
    NSData *data = [handle readDataToEndOfFileAndReturnError:nil];
    if (data == nil) {
        return @"";
    }

    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str ?: @"";
}

@end
