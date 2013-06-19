//
//  BOMedia.m
//  BootChamp
//
//  Created by Kevin Wojniak on 9/9/08.
//  Copyright 2008-2010 Kevin Wojniak. All rights reserved.
//

#import "BOMedia.h"
#import <sys/mount.h>
#import <DiskArbitration/DiskArbitration.h>

// http://macntfs-3g.blogspot.com/
#define KIND_NTFS_3G		@"ntfs-3g"
// http://www.paragon-software.com/home/ntfs-mac/
#define	KIND_PARAGON_NTFS	@"ufsd_NTFS"
// http://www.tuxera.com/products/tuxera-ntfs-for-mac/
#define KIND_TUXERA			@"fusefs_txantfs"

@implementation BOMedia

+ (BOOL)isBootableVolume:(NSString*)path
{
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *sys32Folder = [[path stringByAppendingPathComponent:@"Windows"] stringByAppendingPathComponent:@"System32"];
    if ([fm fileExistsAtPath:sys32Folder]) {
        return YES;
    }
    return NO;
}

+ (NSArray *)allMedia
{
	DASessionRef session = DASessionCreate(kCFAllocatorDefault);
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
	
	CFRelease(session);
	
	return array;
}

@end
