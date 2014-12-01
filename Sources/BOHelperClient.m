//
//  BOHelperClient.m
//  BootChamp
//
//  Created by Kevin Wojniak on 11/29/14.
//  Copyright 2014 Kevin Wojniak. All rights reserved.
//

#import "BOHelperClient.h"
#import "BOLog.h"
#import "BOHelperInstaller.h"
#import "BOTaskAdditions.h"
#import "BOHelper.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>

static NSString* BOHelperSource()
{
    static NSString *src = nil;
    if (!src) {
        src = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"BOHelper"];
    }
    return src;
}

static NSString* BOHelperDestination()
{
    static NSString *dest = nil;
    if (!dest) {
        NSString *toolSrc = BOHelperSource();
        NSString *appSupportPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSLocalDomainMask, YES) objectAtIndex:0];
        NSString *boAppSupport = [appSupportPath stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];
        dest = [boAppSupport stringByAppendingPathComponent:[toolSrc lastPathComponent]];
    }
    return dest;
}

static NSString* BOCreateMD5(const char *path)
{
    if (!path) {
        return nil;
    }
    int f = open(path, O_RDONLY);
    if (f == -1) {
        return nil;
    }
    unsigned char data[CC_MD5_DIGEST_LENGTH];
    char bytes[2048];
    ssize_t bytes_read;
    CC_MD5_CTX c;
    CC_MD5_Init(&c);
    while ((bytes_read = read(f, bytes, sizeof(bytes))) > 0) {
        CC_MD5_Update(&c, bytes, (CC_LONG)bytes_read);
    }
    (void)close(f);
    CC_MD5_Final(data, &c);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            data[0], data[1], data[2], data[3],
            data[4], data[5], data[6], data[7],
            data[8], data[9], data[10],data[11],
            data[12], data[13], data[14], data[15]];
}

BOOL BOHelperInstallationRequired(void)
{
    const char *dest = [BOHelperDestination() fileSystemRepresentation];
    const char *src = [BOHelperSource() fileSystemRepresentation];
    struct stat dest_buf, src_buf;
    bzero(&dest_buf, sizeof(dest_buf));
    bzero(&src_buf, sizeof(src_buf));
    // verify dest exists
    if (stat(dest, &dest_buf) != 0) {
        BOLog(@"%s: Dest doesn't exist: %d", __FUNCTION__, errno);
        return YES;
    }
    // verify dest's permissions
    if ((dest_buf.st_mode & TOOL_MODE) == 0) {
        BOLog(@"%s: Permissions mismatch: %04x", __FUNCTION__, dest_buf.st_mode);
        return YES;
    }
    // verify dest's owner
    if (dest_buf.st_uid != 0) {
        BOLog(@"%s: Owner mismatch: %d", __FUNCTION__, dest_buf.st_uid);
        return YES;
    }
    // verify dest and src has same size
    if (stat(src, &src_buf) != 0 || src_buf.st_size != dest_buf.st_size) {
        BOLog(@"%s: Src sizes mismatch (src=%lld, dest=%lld)", __FUNCTION__, src_buf.st_size, dest_buf.st_size);
        return YES;
    }
    // verify dest and src are equal
    BOOL md5s_equal = NO;
    NSString *md5_src = BOCreateMD5(src);
    NSString *md5_dest = BOCreateMD5(dest);
    if (md5_src && md5_dest) {
        md5s_equal = [md5_src isEqualToString:md5_dest];
    }
    if (!md5s_equal) {
        BOLog(@"%s: Hash mismatch", __FUNCTION__);
        return YES;
    }
    BOLog(@"%s: No auth required", __FUNCTION__);
    return NO;
}

static NSString *const BOInstallErrorDomain = @"BOInstallErrorDomain";

BOInstallStatus BOHelperInstall(void)
{
    NSString *installOutput = nil;
    NSString *toolDest = BOHelperDestination();
    BOLog(@"Installing from %@", toolDest);
    BOTaskReturn ret = [NSTask launchTaskAsRootAtPath:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"BOHelperInstaller"] arguments:@[BOHelperSource(), toolDest] prompt:nil output:&installOutput];
    BOLog(@"HelperInstaller return: %d", (int)ret);
    BOLog(@"Installer output: %@", installOutput);
    switch (ret) {
        case BOTaskLaunched:
            if (installOutput && [installOutput length] > 0) {
                return BOInstallStatusError;
            }
            break;
        case BOTaskAuthorizationCanceled:
            return BOInstallStatusCanceled;
        case BOTaskError:
            return BOInstallStatusError;
    }
    return BOInstallStatusSuccess;
}

int BOHelperRunTask(NSString *path, NSArray *args, NSString **output)
{
    NSString *helperDest = BOHelperDestination();
    BOLog(@"Helper path: %@", helperDest);
    BOLog(@"Helper args: %@", [args description]);
    NSMutableArray *helperArgs = [args mutableCopy];
    [helperArgs insertObject:path atIndex:0];
    NSString *helperOutput = nil;
    const int helperStatus = [NSTask launchTaskAtPath:helperDest arguments:helperArgs output:&helperOutput];
    BOLog(@"Helper status: %d", helperStatus);
    if (helperStatus != EXIT_SUCCESS || !helperOutput) {
        BOLog(@"Helper output (failed): %@", helperOutput);
        return -1;
    }
    
    // Seek to XML plist output, in case there is some other unexpected output
    NSRange range = [helperOutput rangeOfString:@"<?xml"];
    if (range.location == NSNotFound) {
        BOLog(@"Helper output (missing xml): %@", helperOutput);
        return -1;
    }
    
    NSString *xmlOutput = [helperOutput substringFromIndex:range.location];
    NSDictionary *helperDict = [NSPropertyListSerialization propertyListWithData:[xmlOutput dataUsingEncoding:NSUTF8StringEncoding] options:NSPropertyListImmutable format:nil error:nil];
    if (!helperDict) {
        BOLog(@"Invalid helper dictionary");
        return -1;
    }
    
    NSString *blessError = helperDict[kBOHelperError];
    if (blessError) {
        BOLog(@"Invalid helper dictionary");
        return -1;
    }
    
    *output = helperDict[kBOHelperOutput];
    const int status = [helperDict[kBOHelperStatus] intValue];
    BOLog(@"status: %d", status);
    BOLog(@"output:\n%@", *output);
    return status;
}
