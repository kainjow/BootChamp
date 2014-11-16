//
// Created by Kevin Wojniak on 9/5/08.
// Copyright 2008-2014 Kevin Wojniak. All rights reserved.
//

#import "BOTaskAdditions.h"

static void die(NSString *format, ...) {
static int die(NSString *format, ...) {
    va_list ap;
    va_start(ap, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    fprintf(stdout, "%s\n", str.UTF8String);
    exit(EXIT_FAILURE);
    return EXIT_FAILURE;
}

static int run() {
    if (geteuid() != 0) {
        return die(@"Must be run as root.");
    }
    
    NSMutableArray *argv = [[[NSProcessInfo processInfo] arguments] mutableCopy];
    if (argv.count % 2 != 1) {
        return die(@"Invalid number of arguments.");
    }
    [argv removeObjectAtIndex:0]; // pop argv[0]
    NSString *mode = nil;
    NSString *media = nil;
    NSString *legacy = nil;
    while (argv.count > 0) {
        NSString *option = [argv objectAtIndex:0];
        NSString *value = [argv objectAtIndex:1];
        if ([option hasPrefix:@"-"]) {
            option = [option substringFromIndex:1];
        }
        if ([option isEqualToString:@"mode"]) {
            mode = value;
        } else if ([option isEqualToString:@"media"]) {
            media = value;
        } else if ([option isEqualToString:@"legacy"]) {
            legacy = value;
        } else {
            die(@"Invalid arg %@", option);
        }
        [argv removeObjectAtIndex:0];
        [argv removeObjectAtIndex:0];
    }
    if (!mode || (![mode isEqualToString:@"device"] && ![mode isEqualToString:@"mount"])) {
        return die(@"Missing or invalid mode arg.");
    }
    if (!media) {
        return die(@"Missing media arg.");
    }
    if (legacy && (![legacy isEqualToString:@"yes"] && ![legacy isEqualToString:@"no"])) {
        return die(@"Invalid nextonly arg.");
    }
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    if ([mode isEqualToString:@"device"]) {
        [taskArgs addObject:@"--device"];
    } else {
        [taskArgs addObject:@"--mount"];
    }
    [taskArgs addObject:media];
    if ([legacy isEqualToString:@"yes"]) {
        [taskArgs addObject:@"--legacy"];
    }
    [taskArgs addObject:@"--setBoot"];
    [taskArgs addObject:@"--nextonly"];
    [taskArgs addObject:@"--verbose"];
    
    NSString *output = nil;
    int status = [NSTask launchTaskAtPath:@"/usr/sbin/bless" arguments:taskArgs output:&output];
    if (output) {
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (status != 0) {
        return die([@"Bless failed:\n\n" stringByAppendingString:output]);
    }
    
    return EXIT_SUCCESS;
}

int main() {
    @autoreleasepool {
        return run();
    }
}
