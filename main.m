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
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];
	BOStatusMenuController *controller = [[[BOStatusMenuController alloc] init] autorelease];
	[NSApp setDelegate:controller];
	[NSApp run];
	[pool drain];
    return 0;
}

