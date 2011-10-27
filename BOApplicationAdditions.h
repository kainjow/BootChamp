//
//  BOApplicationAdditions.h
//  BootChamp
//
//  Created by Kevin Wojniak on 9/3/09.
//  Copyright 2009-2010 Kevin Wojniak. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface NSApplication (BOApplicationAdditions)

- (void)addToLoginItems;
- (void)removeFromLoginItems;

@end
