//
//  BOEFI.m
//  BootChamp
//
//  Created by Kevin Wojniak on 11/10/14.
//  Copyright 2014 Kevin Wojniak. All rights reserved.
//

#import "BOEFI.h"
#import "BOLog.h"
#import "BOTaskAdditions.h"
#import "BOMedia.h"

static int launchTask(NSString *path, NSArray *arguments, NSString **output)
{
    int ret = [NSTask launchTaskAtPath:path arguments:arguments output:output];
    if (output && *output) {
        *output = [*output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return ret;
}

static BOOL diskMountPoint(NSString *diskutil, NSString *diskID, NSString **mountPoint)
{
    *mountPoint = nil;
    NSString *output = nil;
    if (launchTask(diskutil, @[@"info", @"-plist", diskID], &output) != 0) {
        BOLog(@"%s: can't get info for %@: %@", __FUNCTION__, diskID, output);
        return NO;
    }
    NSData *data = [output dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:nil];
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) {
        BOLog(@"%s: invalid output: %@", __FUNCTION__, output);
        return NO;
    }
    NSString *tmpMountPoint = dict[@"MountPoint"];
    if (tmpMountPoint && [tmpMountPoint length] > 0) {
        *mountPoint = tmpMountPoint;
    }
    return YES;
}

static BOOL checkDisk(NSString *diskID)
{
    NSString *diskutil = @"/usr/sbin/diskutil";
    BOOL unmountEFI = NO;
    NSString *mountPoint = nil;
    if (!diskMountPoint(diskutil, diskID, &mountPoint)) {
        return NO;
    }
    if (!mountPoint) {
        NSString *output = nil;
        if (launchTask(diskutil, @[@"mount", @"readOnly", diskID], &output) != 0) {
            BOLog(@"%s: can't mount %@: %@", __FUNCTION__, diskID, output);
            return NO;
        }
        if (!diskMountPoint(diskutil, diskID, &mountPoint) || !mountPoint) {
            return NO;
        }
        unmountEFI = YES;
    }
    
    BOLog(@"%s: mount point = %@:", __FUNCTION__, mountPoint);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSEnumerator *direnum = [fm enumeratorAtPath:mountPoint];
    NSString *file;
    while ((file = [direnum nextObject]) != nil) {
        if ([file hasPrefix:@".Spotlight"] || [file hasPrefix:@".Trashes"]) {
            continue;
        }
        BOLog(@"%s: %@", __FUNCTION__, file);
    }
    
    BOOL isDir;
    BOOL haveBootFile = [fm fileExistsAtPath:[mountPoint stringByAppendingPathComponent:@"efi/boot/bootx64.efi"] isDirectory:&isDir] && !isDir;
    BOOL haveMSDir = [fm fileExistsAtPath:[mountPoint stringByAppendingPathComponent:@"efi/microsoft/boot"] isDirectory:&isDir] && isDir;
    
    if (unmountEFI) {
        // We don't care when/if this finishes
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            (void)launchTask(diskutil, @[@"unmount", diskID], nil);
        });
    }
    
    BOOL bootable = haveBootFile && haveMSDir;
    BOLog(@"%s: bootable EFI = %d", __FUNCTION__, bootable);
    return bootable;
}

static BOOL isDiskIDValid(NSString *diskID) {
    DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, [BOMedia session], diskID.UTF8String);
    if (!disk) {
        BOLog(@"%s: NULL DADisk for %@", __FUNCTION__, diskID);
        return NO;
    }
    NSDictionary *desc = (__bridge_transfer NSDictionary*)DADiskCopyDescription(disk);
    CFRelease(disk);
    if (!desc) {
        BOLog(@"%s: NULL desc for %@", __FUNCTION__, diskID);
        return NO;
    }
    BOLog(@"%s: %@ is valid", __FUNCTION__, diskID);
    return YES;
}

NSString* BOBootableEFI(void)
{
    BOLog(@"%s start", __FUNCTION__);
    // This is hacky. Should probably use DiskArbitration
    for (int i = 0; i < 4; ++i) {
        NSString *diskID = [NSString stringWithFormat:@"disk%ds1", i];
        if (!isDiskIDValid(diskID)) {
            continue;
        }
        BOLog(@"%s: checking %@", __FUNCTION__, diskID);
        if (checkDisk(diskID)) {
            return [@"/dev/" stringByAppendingString:diskID];
        }
    }
    BOLog(@"%s: no bootable EFI found", __FUNCTION__);
    return nil;
}
