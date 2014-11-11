//
//  BOStatusMenuController.m
//  BootChamp
//
//  Created by Kevin Wojniak on 7/6/08.
//  Copyright 2008-2012 Kevin Wojniak. All rights reserved.
//

#import "BOStatusMenuController.h"
#import "BOBoot.h"
#import "BOMedia.h"
#import "BOHelperInstaller.h"
#import "NSApplication+LoginItems.h"
#import <Sparkle/Sparkle.h>
#import "BOLog.h"

#define BOPrefsLaunchAtStartup	@"LaunchAtStartup"

@implementation BOStatusMenuController

+ (void)initialize
{
	NSDictionary *defaults = @{BOPrefsLaunchAtStartup : @YES};
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

+ (NSImage *)statusImage
{
	NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(22.0, 22.0)];
	NSRect bounds = NSMakeRect(0.0, 0.0, [img size].width, [img size].height);
	NSSize size = NSMakeSize(5.0, 5.0);
	NSRect drawBounds = NSZeroRect;
	drawBounds.size = NSMakeSize(size.width*2+1.5, size.height*2+1.5);
	drawBounds.origin = NSMakePoint(NSMinX(bounds) + floor((NSWidth(bounds)-NSWidth(drawBounds))/2),
									NSMinY(bounds) + floor((NSHeight(bounds)-NSHeight(drawBounds))/2));
	bounds = drawBounds;
	NSBezierPath *bz = nil;
	CGFloat colors[] = {0.1, 0.25, 0.4, 0.55};
	
	[img lockFocus];
	
	NSAffineTransform *at = [NSAffineTransform transform];
	[at translateXBy:NSWidth(bounds) yBy:NSHeight(bounds)];
	[at rotateByDegrees:45.0];
	[at translateXBy:-NSWidth(bounds) yBy:-NSHeight(bounds)];
	[at concat];
	
	// top left
	[[NSColor colorWithCalibratedWhite:colors[3] alpha:1.0] set];
	bz = [NSBezierPath bezierPath];
	[bz moveToPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds))];
	[bz lineToPoint:NSMakePoint(NSMinX(bounds)+size.width, NSMaxY(bounds))];
	[bz lineToPoint:NSMakePoint(NSMinX(bounds)+size.width, NSMaxY(bounds)-size.height)];
	[bz lineToPoint:NSMakePoint(NSMinX(bounds), NSMaxY(bounds)-size.height)];
	[bz fill];

	// top right
	[[NSColor colorWithCalibratedWhite:colors[0] alpha:1.0] set];
	bz = [NSBezierPath bezierPath];
	[bz moveToPoint:NSMakePoint(NSMaxX(bounds)-size.width, NSMaxY(bounds))];
	[bz lineToPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds))];
	[bz lineToPoint:NSMakePoint(NSMaxX(bounds), NSMaxY(bounds)-size.height)];
	[bz lineToPoint:NSMakePoint(NSMaxX(bounds)-size.width, NSMaxY(bounds)-size.height)];
	[bz fill];

	// bottom right
	[[NSColor colorWithCalibratedWhite:colors[1] alpha:1.0] set];
	bz = [NSBezierPath bezierPath];
	[bz moveToPoint:NSMakePoint(NSMaxX(bounds)-size.width, NSMinY(bounds)+size.height)];
	[bz lineToPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds)+size.height)];
	[bz lineToPoint:NSMakePoint(NSMaxX(bounds), NSMinY(bounds))];
	[bz lineToPoint:NSMakePoint(NSMaxX(bounds)-size.width, NSMinY(bounds))];
	[bz fill];

	// bottom left
	[[NSColor colorWithCalibratedWhite:colors[2] alpha:1.0] set];
	bz = [NSBezierPath bezierPath];
	[bz moveToPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds)+size.height)];
	[bz lineToPoint:NSMakePoint(NSMinX(bounds)+size.width, NSMinY(bounds)+size.height)];
	[bz lineToPoint:NSMakePoint(NSMinX(bounds)+size.width, NSMinY(bounds))];
	[bz lineToPoint:NSMakePoint(NSMinX(bounds), NSMinY(bounds))];
	[bz fill];
	
	[img unlockFocus];
	[img setTemplate:YES];
	return img;
}

- (void)checkPrefs
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:BOPrefsLaunchAtStartup])
		[NSApp addToLoginItems];
	else
		[NSApp removeFromLoginItems];
}

- (void)updateBootMenuTitle
{
	NSString *restartTitle = NSLocalizedString(@"Restart into Windows", "restart into windows menu item");
	NSString *altRestartTitle;
    if ([bootMenuItem representedObject]) {
        altRestartTitle = [NSString stringWithFormat:NSLocalizedString(@"Restart into %@", "restart into windows alternative menu item"), [[bootMenuItem representedObject] name]];
    } else {
        altRestartTitle = restartTitle;
    }
	if (BOAuthorizationRequired() && ([bootMenuItem target] || [bootMenuItem submenu])) {
        // Add ellipsis character to indicate the user needs to authenticate
		restartTitle = [restartTitle stringByAppendingString:@"\u2026"];
		altRestartTitle = [altRestartTitle stringByAppendingString:@"\u2026"];
	}
	[bootMenuItem setTitle:restartTitle];
    [altBootMenuItem setTitle:altRestartTitle];
}

- (void)updateBootMenu:(NSMenuItem*)menuItem withMedia:(NSArray*)media
{
	if (![media count]) {
		// no media
		[menuItem setTarget:nil];
		[menuItem setAction:nil];
		[menuItem setSubmenu:nil];
		[menuItem setRepresentedObject:nil];
	} else {
		if ([media count] == 1) {
			[menuItem setTarget:self];
			[menuItem setAction:@selector(bootWindows:)];
			[menuItem setSubmenu:nil];
			[menuItem setRepresentedObject:[media lastObject]];
		} else {
			// multiple media
			NSMenu *submenu = [[NSMenu alloc] init];
			for (BOMedia *m in media) {
				NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:m.name action:@selector(bootWindows:) keyEquivalent:@""];
				[item setTarget:self];
				[item setRepresentedObject:m];
				NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:m.mountPoint];
				[icon setSize:NSMakeSize(16.0, 16.0)];
				[item setImage:icon];
				[submenu addItem:item];
			}
			[menuItem setTarget:nil];
			[menuItem setAction:nil];
			[menuItem setSubmenu:submenu];
			[menuItem setRepresentedObject:nil];
		}
	}
}

- (void)updateBootMenuWithMedia:(NSArray *)media
{
    BOLog(@"Update menu with media: %@", media);
	[self updateBootMenuTitle];
    [self updateBootMenu:bootMenuItem withMedia:media];
    [self updateBootMenu:altBootMenuItem withMedia:media];
}

- (void)updateBootMenu
{
	[bootMenuItem setTitle:NSLocalizedString(@"Updating\u2026", "updating drives menu item")];
	[bootMenuItem setTarget:nil];
	[bootMenuItem setAction:nil];
	[bootMenuItem setSubmenu:nil];
	[bootMenuItem setRepresentedObject:nil];
	
	// Load media objects in the background and call back to self with updateBootMenuWithMedia: when done
	dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(queue, ^{
		NSArray *media = [BOMedia allMedia];
		dispatch_async(dispatch_get_main_queue(), ^{
			[self updateBootMenuWithMedia:media];
		});
	});
}

- (void)menuNeedsUpdate:(NSMenu * __unused)menu
{
	[self updateBootMenuTitle];
}

- (id)init
{
    if ((self = [super init]) != nil) {
        (void)[BOLog sharedLog]; // init log;
    }
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification * __unused)notif
{
    BOLog(@"%@ %@", [[NSProcessInfo processInfo] processName], [[NSBundle mainBundle] objectForInfoDictionaryKey:(id)kCFBundleVersionKey]);
    NSString *output = nil;
    (void)[NSTask launchTaskAtPath:@"/usr/sbin/diskutil" arguments:@[@"list"] output:&output];
    BOLog(@"disks\n%@", output);
    (void)[NSTask launchTaskAtPath:@"/sbin/mount" arguments:nil output:&output];
    BOLog(@"mount\n%@", output);
    
	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	[statusItem setHighlightMode:YES];
    
    // Allow the user to specify a custom image via:
    // $ defaults write com.kainjow.BootChamp StatusImage <path>
    NSString *statusImagePath = [[NSUserDefaults standardUserDefaults] objectForKey:@"StatusImage"];
    NSImage *statusImage = nil;
    if (statusImagePath != nil) {
        statusImage = [[NSImage alloc] initWithContentsOfFile:statusImagePath];
    }
    if (statusImage == nil) {
        statusImage = [[self class] statusImage];
    }
	[statusItem setImage:statusImage];
	
	NSMenu *menu = [[NSMenu alloc] init];
	[menu setDelegate:self];
	
	// restart into windows
	bootMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    altBootMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:Nil keyEquivalent:@""];
    [altBootMenuItem setAlternate:YES];
    [altBootMenuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
    
	[menu addItem:bootMenuItem];
    [menu addItem:altBootMenuItem];
	[self updateBootMenu];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(updateBootMenu) name:NSWorkspaceDidMountNotification object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(updateBootMenu) name:NSWorkspaceDidUnmountNotification object:nil];
	
	[menu addItem:[NSMenuItem separatorItem]];
	
	NSMenuItem *prefsMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Preferences", "preferences title menu item") action:nil keyEquivalent:@""];
    NSMenu *prefsSubMenu = [[NSMenu alloc] init];
    [prefsMenuItem setSubmenu:prefsSubMenu];
	NSMenuItem *menuItem;
	menuItem = [prefsSubMenu addItemWithTitle:NSLocalizedString(@"Launch at startup", "launch at startup menu item") action:@selector(preferenceAction:) keyEquivalent:@""];
	[menuItem setIndentationLevel:1];
	[menuItem setRepresentedObject:BOPrefsLaunchAtStartup];
	if ([[NSUserDefaults standardUserDefaults] boolForKey:BOPrefsLaunchAtStartup])
		[menuItem setState:NSOnState];

	[menu addItemWithTitle:NSLocalizedString(@"BootChamp Help", "help menu item") action:@selector(showHelp:) keyEquivalent:@""];
	[menu addItemWithTitle:NSLocalizedString(@"Check for Updates\u2026", "check for updates menu item") action:@selector(checkforUpdates:) keyEquivalent:@""];
	[menu addItem:[NSMenuItem separatorItem]];
	[menu addItemWithTitle:NSLocalizedString(@"Quit", "quit menu item") action:@selector(quit:) keyEquivalent:@""];
	[[menu itemArray] makeObjectsPerformSelector:@selector(setTarget:) withObject:self];
	
	[statusItem setMenu:menu];
	
	[self checkPrefs];
    
    updater = [SUUpdater sharedUpdater];
}

- (void)bootWindows:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	NSError *error = nil;
	if (BOBoot([sender representedObject], &error))
		return;
	[NSApp activateIgnoringOtherApps:YES]; // app may have gone inactive from auth dialog
	NSString *msg = nil, *info = nil;
	switch ([error code]) {
		case BOBootInvalidMediaError:
			msg = NSLocalizedString(@"BootChamp was unable to find a Windows volume", nil);
			info = NSLocalizedString(@"Supported file systems are FAT32 and NTFS.", nil);
			break;
		case BOBootAuthorizationError:
			msg = NSLocalizedString(@"BootChamp was unable to set your Windows volume as the temporary startup disk", nil);
			info = NSLocalizedString(@"Authentication may have failed.", nil);
			break;
		case BOBootInstallationFailed:
			msg = NSLocalizedString(@"BootChamp was unable to install its required helper tool.", nil);
			info = [error localizedDescription];
			break;
		case BOBootInternalError:
			msg = NSLocalizedString(@"BootChamp was unable to set your Windows volume as the temporary startup disk", nil);
			info = [error localizedDescription];
			break;
		case BOBootRestartFailedError:
			msg = NSLocalizedString(@"BootChamp was unable to restart your computer", nil);
			info = NSLocalizedString(@"Please restart your computer manually.", nil);
			break;
		default:
			break;
	}
	if (msg) {
		NSAlert *alert = [[NSAlert alloc] init];
		[alert setMessageText:msg];
		if (info)
			[alert setInformativeText:info];
		[alert runModal];
	}
}

- (void)showHelp:(id __unused)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	NSURL *helpURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"help.htm" ofType:nil]];
	[[NSWorkspace sharedWorkspace] openURLs:@[helpURL] withAppBundleIdentifier:@"com.apple.helpviewer" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifiers:NULL];
}

- (void)preferenceAction:(id __unused)sender
{
	NSString *key = [sender representedObject];
	NSInteger newState = ([sender state] == NSOnState ? NSOffState : NSOnState);
	[sender setState:newState];
	[[NSUserDefaults standardUserDefaults] setBool:(newState == NSOnState ? YES : NO) forKey:key];
	
	[self checkPrefs];
}

- (void)checkforUpdates:(id)sender
{
    [updater checkForUpdates:sender];
}

- (void)quit:(id __unused)sender
{
	[NSApp terminate:nil];
}

@end
