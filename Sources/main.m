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

int main(void)
{
    @autoreleasepool {
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

