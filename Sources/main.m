//
//  main.m
//  BootChamp
//
//  Created by Kevin Wojniak on 7/4/07.
//  Copyright 2007-2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BOStatusMenuController.h"
#import "BOBoot.h"
#import "BOLog.h"
#include <sys/sysctl.h>

static int restart()
{
    BOStatusMenuController *controller = [[BOStatusMenuController alloc] init];
    BOLog(@"Running CLI");
    NSArray *media = controller.media;
    NSError *err = nil;
    if (!media || media.count == 0) {
        return BOBootInvalidMediaError + 1;
    } else if (!BOBoot([media objectAtIndex:0], &err, NO)) {
        return (int)err.code + 1;
    }
    return 0;
}

static NSString* hwmodel() {
    size_t len = 0;
    if (sysctlbyname("hw.model", NULL, &len, NULL, 0) != 0 || len == 0) {
        return nil;
    }
    NSMutableData *bytes = [NSMutableData dataWithLength:len];
    (void)sysctlbyname("hw.model", [bytes mutableBytes], &len, NULL, 0);
    return [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
}

int main(void)
{
    @autoreleasepool {
        BOLog(@"App: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]);
        BOLog(@"OS: %@", [NSProcessInfo processInfo].operatingSystemVersionString);
        BOLog(@"HW: %@", hwmodel());
        if ([[[NSProcessInfo processInfo] arguments] containsObject:@"restart"]) {
            return restart();
        }
        NSApplication *app = [NSApplication sharedApplication];
        BOStatusMenuController *controller = [[BOStatusMenuController alloc] init];
        [app setDelegate:controller];
        BOLog(@"Running GUI");
        [app run];
    }
    return 0;
}

