//
//  main.m
//  BootChamp
//
//  Created by Kevin Wojniak on 7/4/07.
//  Copyright 2007-2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BOStatusMenuController.h"

int main(void)
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        BOStatusMenuController *controller = [[BOStatusMenuController alloc] init];
        [app setDelegate:controller];
        [app run];
    }
    return 0;
}

