//
//  BOBoot.m
//  BootChamp
//
//  Created by Kevin Wojniak on 7/4/07.
//  Copyright 2007-2010 Kevin Wojniak. All rights reserved.
//

#import "BOBoot.h"
#import "BOMedia.h"
#import "BOLog.h"
#import "BOHelperClient.h"

static NSString *const BOBootErrorDomain = @"BOBootErrorDomain";

static BOOL BORestart()
{
#if 0
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to restart"];
    NSDictionary *dict = nil;
    return [script executeAndReturnError:&dict] != nil;
#else
	return NO; // for testing
#endif
}

BOOL BOBoot(BOMedia *media, NSError **error)
{
	if (!media) {
        if (error) {
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInvalidMediaError userInfo:nil];
        }
		return NO;
	}
	
	NSMutableArray *args = [NSMutableArray array];
	if (media.deviceName) {
        [args addObject:@"--device"];
		[args addObject:media.deviceName];
	} else {
        [args addObject:@"--mount"];
		[args addObject:media.mountPoint];
	}
    [args addObject:@"--setBoot"];
    [args addObject:@"--nextonly"];
    if (media.legacy) {
        [args addObject:@"--legacy"];
    }
    [args addObject:@"--verbose"];
	
    NSString *blessOutput = nil;
    const int blessStatus = BOHelperRunTask(@"/usr/sbin/bless", args, &blessOutput);
    BOLog(@"blessStatus: %d", blessStatus);
    BOLog(@"blessOutput:\n%@", blessOutput);
    
    if (blessStatus != EXIT_SUCCESS) {
        if (error) {
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:@{NSLocalizedDescriptionKey : blessOutput}];
        }
		return NO;
	}
	
	if (!BORestart()) {
        if (error) {
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootRestartFailedError userInfo:nil];
        }
		return NO;
	}
	
	return YES;
}
