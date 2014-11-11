//
//  BOMedia.m
//  BootChamp
//
//  Created by Kevin Wojniak on 9/9/08.
//  Copyright 2008-2014 Kevin Wojniak. All rights reserved.
//

#import "BOMedia.h"
#import "BOLog.h"
#import <sys/mount.h>

// http://macntfs-3g.blogspot.com/
#define KIND_NTFS_3G		@"ntfs-3g"
// http://www.paragon-software.com/home/ntfs-mac/
#define	KIND_PARAGON_NTFS	@"ufsd_NTFS"
// http://www.tuxera.com/products/tuxera-ntfs-for-mac/
#define KIND_TUXERA			@"fusefs_txantfs"

@interface NSFileManager (BOMedia)
- (BOOL)fileExistsAtPathIgnoringCase:(NSString*)path isDirectory:(BOOL*)isDir;
@end
@implementation NSFileManager (BOMedia)
- (BOOL)fileExistsAtPathIgnoringCase:(NSString*)path isDirectory:(BOOL*)isDir
{
    NSArray *components = [path pathComponents];
    NSString *truePath = [components objectAtIndex:0];
    for (NSUInteger i = 1; i < [components count]; ++i) {
        NSString *givenComponent = [components objectAtIndex:i];
        BOOL isLastComponent = (i == [components count] - 1);
        for (NSString *trueComponent in [self contentsOfDirectoryAtPath:truePath error:nil]) {
            if ([trueComponent caseInsensitiveCompare:givenComponent] == NSOrderedSame) {
                truePath = [truePath stringByAppendingPathComponent:trueComponent];
                if (isLastComponent) {
                    return [self fileExistsAtPath:truePath isDirectory:isDir];
                }
                break;
            }
        }
    }
    return NO;
}
@end

@interface NSString (BOMedia)
- (NSString*)stringByAppendingPathComponents:(NSArray*)components;
@end
@implementation NSString (BOMedia)
- (NSString*)stringByAppendingPathComponents:(NSArray*)components
{
    NSString *s = self;
    for (NSString *comp in components) {
        s = [s stringByAppendingPathComponent:comp];
    }
    return s;
}
@end

@implementation BOMedia

+ (BOOL)isBootableVolume:(NSString*)volume
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    if (!volume || ![fm fileExistsAtPath:volume]) {
        return NO;
    }
    NSArray *paths = @[
        [volume stringByAppendingPathComponents:@[@"Windows", @"System32"]],
    ];
    for (NSString *path in paths) {
        BOOL isDir = NO;
        // NTFS is case sensitive.
        // On 10.8, fileExistsAtPath: seems to work just fine with case insensitive paths,
        // but according to a user with 10.6 it does not work, so I had to implement
        // a case insensitive alternative.
        if ([fm fileExistsAtPathIgnoringCase:path isDirectory:&isDir] && isDir == YES) {
            return YES;
        }
    }
    return NO;
}

+ (DASessionRef)session
{
    static DASessionRef session = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = DASessionCreate(kCFAllocatorDefault);
        if (!session) {
            BOLog(@"DASessionCreate failed.");
        }
    });
    return session;
}

+ (NSArray *)allMedia
{
    DASessionRef session = [self session];
    if (!session) {
        NSLog(@"DASessionCreate failed.");
        return nil;
    }
	
	NSArray *allowedKinds = @[@"ntfs", @"msdos", @"ufsd", @"cd9660", KIND_NTFS_3G, KIND_PARAGON_NTFS, KIND_TUXERA];
	
	NSMutableArray *array = [NSMutableArray array];
	struct statfs *buf = NULL;
	int count = getmntinfo(&buf, 0);
	for (int i=0; i<count; i++) {
		const char *bsdName = buf[i].f_mntfromname;
		DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName);
		if (!disk) {
			NSLog(@"DADiskCreateFromBSDName failed for %s", bsdName);
			continue;
		}
		
		CFDictionaryRef desc = DADiskCopyDescription(disk);
		CFRelease(disk);
		if (!desc) {
			continue;
		}

		BOMedia *media = [[BOMedia alloc] init];
		
		BOOL isValidBootCampVolume = NO;
		
		NSString *volKind = (NSString *)CFDictionaryGetValue(desc, kDADiskDescriptionVolumeKindKey);
		NSURL *mountURL = (NSURL *)CFDictionaryGetValue(desc, kDADiskDescriptionVolumePathKey);
		
		for (NSString *kind in allowedKinds) {
			if (volKind && [kind rangeOfString:volKind options:NSCaseInsensitiveSearch].location != NSNotFound) {
				isValidBootCampVolume = YES;
				
				if ([kind isEqualToString:KIND_NTFS_3G] || [kind isEqualToString:KIND_TUXERA]) {
					// When NTFS-3G/MacFUSE is installed we need to use
					// bless's --device option instead of --folder
					// for some reason --folder doesn't work in this situation.
					media.deviceName = [NSString stringWithUTF8String:bsdName];
				}
				break;
			}
		}
		
        NSString *mountPoint = [mountURL path];
		if (isValidBootCampVolume && [self isBootableVolume:mountPoint]) {
			media.mountPoint = mountPoint;
            if (mountPoint != nil) {
                media.name = [mountPoint lastPathComponent];
            } else {
                media.name = (NSString*)CFDictionaryGetValue(desc, kDADiskDescriptionVolumeNameKey);
            }
			[array addObject:media];
		}
		
		CFRelease(desc);
	}
	
	return array;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<%@: %p> mount=%@, dev=%@, name=%@",
            [self className], self, self.mountPoint, self.deviceName, self.name];
}

@end
