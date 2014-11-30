//
// Created by Kevin Wojniak on 9/5/08.
// Copyright 2008-2014 Kevin Wojniak. All rights reserved.
//

#import "BOTaskAdditions.h"
#import "BOHelper.h"

static int die(NSString *format, ...) NS_FORMAT_FUNCTION(1,2);

static void outputDict(NSDictionary *dict) {
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dict format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    [NSFileHandle.fileHandleWithStandardOutput writeData:data];
}

static int die(NSString *format, ...) {
    va_list ap;
    va_start(ap, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    outputDict(@{kBOHelperError : str});
    return EXIT_FAILURE;
}

static int run() {
    if (geteuid() != 0) {
        return die(@"Must be run as root.");
    }
    
    NSArray *argv = [[NSProcessInfo processInfo] arguments];
    const NSUInteger argvCount = argv.count;
    if (argvCount <= 1) {
        return die(@"Invalid number of arguments.");
    }
    NSString *taskPath = argv[1];
    NSArray *taskArgs = nil;
    if (argvCount > 2) {
        taskArgs = [argv subarrayWithRange:NSMakeRange(2, argvCount - 2)];
    }
    
    NSString *output = nil;
    int status = [NSTask launchTaskAtPath:taskPath arguments:taskArgs output:&output];
    if (output) {
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    outputDict(@{
        kBOHelperStatus : @(status),
        kBOHelperOutput : output ? output : @""
    });
    return EXIT_SUCCESS;
}

int main() {
    @autoreleasepool {
        return run();
    }
}
