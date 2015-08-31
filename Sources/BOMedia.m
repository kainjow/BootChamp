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
    BOLog(@"%s: start", __FUNCTION__);

    DASessionRef session = [self session];
    if (!session) {
        BOLog(@"%s: DASessionCreate failed.", __FUNCTION__);
        return nil;
    }
	
	NSArray *allowedKinds = @[@"ntfs", @"msdos", @"ufsd", @"cd9660", KIND_NTFS_3G, KIND_PARAGON_NTFS, KIND_TUXERA];
	
	NSMutableArray *array = [NSMutableArray array];
	struct statfs *buf = NULL;
	int count = getmntinfo(&buf, 0);
    if (count == 0) {
        BOLog(@"%s: getmntinfo failed: %s", __FUNCTION__, strerror(errno));
        return nil;
    }
    
    BOLog(@"%s: getmntinfo count: %d", __FUNCTION__, count);
	for (int i=0; i<count; i++) {
		const char *bsdName = buf[i].f_mntfromname;
        BOLog(@"%s: getmntinfo[%d]: %s", __FUNCTION__, i, bsdName);

        DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, bsdName);
		if (!disk) {
			BOLog(@"%s:   DADiskCreateFromBSDName failed", __FUNCTION__);
			continue;
		}
		
		CFDictionaryRef desc = DADiskCopyDescription(disk);
		CFRelease(disk);
		if (!desc) {
            BOLog(@"%s:   DADiskCopyDescription failed", __FUNCTION__);
			continue;
		}

		BOOL isValidBootCampVolume = NO;
		
		NSString *volKind = (NSString *)CFDictionaryGetValue(desc, kDADiskDescriptionVolumeKindKey);
		NSURL *mountURL = (NSURL *)CFDictionaryGetValue(desc, kDADiskDescriptionVolumePathKey);
		
        BOLog(@"%s:   volKind = %@", __FUNCTION__, volKind);
        BOLog(@"%s:   mountURL = %@", __FUNCTION__, mountURL);
        
        BOMedia *media = [[BOMedia alloc] init];

        for (NSString *kind in allowedKinds) {
			if (volKind && [kind rangeOfString:volKind options:NSCaseInsensitiveSearch].location != NSNotFound) {
				isValidBootCampVolume = YES;
                
                if ([kind isEqualToString:KIND_NTFS_3G] || [kind isEqualToString:KIND_TUXERA]) {
                    // Third-party NTFS drivers don't work with bless' --mount option.
                    // At least with Tuxera, bless fails with "Can't statfs /Volumes/BOOTCAMP"
                    // so use the device variant instead.
                    media.deviceName = [NSString stringWithUTF8String:bsdName];
                    BOLog(@"%s:   deviceName set", __FUNCTION__);
                }
				break;
			}
		}
        
        BOLog(@"%s:   isValidBootCampVolume = %d", __FUNCTION__, isValidBootCampVolume);
		
        media.legacy = YES;
        NSString *mountPoint = [mountURL path];
        const BOOL isBootable = [self isBootableVolume:mountPoint];
        
        BOLog(@"%s:   mountPoint = %@", __FUNCTION__, mountPoint);
        BOLog(@"%s:   isBootable = %d", __FUNCTION__, isBootable);
        
		if (isValidBootCampVolume && isBootable) {
			media.mountPoint = mountPoint;
            if (mountPoint != nil) {
                media.name = [mountPoint lastPathComponent];
            } else {
                media.name = (NSString*)CFDictionaryGetValue(desc, kDADiskDescriptionVolumeNameKey);
            }
            BOLog(@"%s:   media.name = %@", __FUNCTION__, media.name);
			[array addObject:media];
		}
		
		CFRelease(desc);
	}
	
	return array;
}

- (NSString*)description
{
    return [NSString stringWithFormat:@"<%@: %p> mount=%@, dev=%@, name=%@, legacy=%d",
            [self className], self, self.mountPoint, self.deviceName, self.name, self.legacy];
}

@end
