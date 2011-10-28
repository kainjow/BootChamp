//
//  BOStatusMenuController.h
//  BootChamp
//
//  Created by Kevin Wojniak on 7/6/08.
//  Copyright 2008-2010 Kevin Wojniak. All rights reserved.
//

#import <AppKit/AppKit.h>

#if MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_6
@interface BOStatusMenuController : NSObject <NSMenuDelegate>
#else
@interface BOStatusMenuController : NSObject
#endif
{
	NSStatusItem *statusItem;
	NSMenuItem *bootMenuItem;
}

@end
