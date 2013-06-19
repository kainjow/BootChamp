//
//  main.m
//  BootChamp
//
//  Created by Kevin Wojniak on 7/4/07.
//  Copyright 2007-2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BOStatusMenuController.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
        [NSApplication sharedApplication];
        BOStatusMenuController *controller = [[BOStatusMenuController alloc] init];
        [NSApp setDelegate:controller];
        [NSApp run];
    }
    return 0;
}

