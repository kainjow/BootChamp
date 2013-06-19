//
//  BOApplicationAdditions.m
//  BootChamp
//
//  Created by Kevin Wojniak on 9/3/09.
//  Copyright 2009-2010 Kevin Wojniak. All rights reserved.
//

#import "BOApplicationAdditions.h"


@implementation NSApplication (BOApplicationAdditions)

- (BOOL)isAppInstalled:(CFStringRef)appName inList:(LSSharedFileListRef)list item:(LSSharedFileListItemRef *)item
{
	CFArrayRef loginItems = LSSharedFileListCopySnapshot(list, NULL);
	if (!loginItems)
		return NO;
	
	BOOL ret = NO;
	for (CFIndex i=0; i<CFArrayGetCount(loginItems); i++)
	{
		LSSharedFileListItemRef listItem = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(loginItems, i);
		CFStringRef displayName = LSSharedFileListItemCopyDisplayName(listItem);
		if (displayName)
		{
			if (CFStringCompare(displayName, appName, kCFCompareCaseInsensitive) == kCFCompareEqualTo)
			{
				ret = YES;
				if (item)
				{
					*item = listItem;
					CFRetain(*item);
				}
			}
			
			CFRelease(displayName);
			
			if (ret)
				break;
		}
	}
	
	CFRelease(loginItems);
	
	return ret;
}

- (void)addToLoginItems
{
	LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (!list)
		return;
	
	CFStringRef appName = (__bridge CFStringRef)[[NSProcessInfo processInfo] processName];
	
	if (![self isAppInstalled:appName inList:list item:NULL])
	{
		CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
		LSSharedFileListItemRef newItem = LSSharedFileListInsertItemURL(list, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
		if (newItem)
			CFRelease(newItem);
	}
	
	CFRelease(list);
}

- (void)removeFromLoginItems
{
	LSSharedFileListRef list = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
	if (!list)
		return;
	
	CFStringRef appName = (__bridge CFStringRef)[[NSProcessInfo processInfo] processName];
	LSSharedFileListItemRef item = NULL;
	if ([self isAppInstalled:appName inList:list item:&item] && item)
	{
		LSSharedFileListItemRemove(list, item);
		CFRelease(item);
	}
	
	CFRelease(list);
}

@end