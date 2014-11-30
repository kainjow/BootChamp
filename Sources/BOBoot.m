//
//  BOBoot.m
//  BootChamp
//
//  Created by Kevin Wojniak on 7/4/07.
//  Copyright 2007-2010 Kevin Wojniak. All rights reserved.
//

#import "BOBoot.h"
#import "BOMedia.h"
#import "BOTaskAdditions.h"
#import "BOHelperInstaller.h"
#import "BOLog.h"
#import "BOHelper.h"
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>

static NSString *const BOBootErrorDomain = @"BOBootErrorDomain";

static BOOL BORestart()
{
#if 1
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to restart"];
    NSDictionary *dict = nil;
    return [script executeAndReturnError:&dict] != nil;
#else
	return NO; // for testing
#endif
}

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

BOOL BOAuthorizationRequired(void)
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

BOOL BOBoot(BOMedia *media, NSError **error)
{
	if (!media) {
        if (error) {
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInvalidMediaError userInfo:nil];
        }
		return NO;
	}
	
	NSString *installOutput = nil;
	NSString *toolDest = BOHelperDestination();
	if (BOAuthorizationRequired()) {
		NSString *prompt = [NSString stringWithFormat:NSLocalizedString(@"Administrative access is needed to change your startup disk to \"%@\".", ""), media.name];
		BOTaskReturn ret = [NSTask launchTaskAsRootAtPath:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"BOHelperInstaller"] arguments:@[BOHelperSource(), toolDest] prompt:prompt output:&installOutput];
		switch (ret) {
			case BOTaskLaunched:
				if (installOutput && [installOutput length] > 0) {
                    if (error) {
						*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInstallationFailed userInfo:@{NSLocalizedDescriptionKey : installOutput}];
                    }
					return NO;
				}
				break;
			case BOTaskAuthorizationCanceled:
                if (error) {
					*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootAuthorizationCanceled userInfo:nil];
                }
				return NO;
			case BOTaskError:
                if (error) {
					*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootAuthorizationError userInfo:installOutput ? @{NSLocalizedDescriptionKey : installOutput} : nil];
                }
				return NO;
		}
	}
	
	NSMutableArray *args = [NSMutableArray array];
    [args addObject:@"/usr/sbin/bless"];
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
	
    BOLog(@"Helper path: %@", toolDest);
    BOLog(@"Helper args: %@", [args description]);
    NSString *helperOutput = nil;
	const int helperStatus = [NSTask launchTaskAtPath:toolDest arguments:args output:&helperOutput];
    BOLog(@"Helper status: %d", helperStatus);
    if (helperStatus != EXIT_SUCCESS || !helperOutput) {
        BOLog(@"Helper output (failed): %@", helperOutput);
        if (error) {
            *error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:helperOutput ? @{NSLocalizedDescriptionKey : helperOutput} : nil];
        }
        return NO;
	}
	
    // Seek to XML plist output, in case there is some other unexpected output
    NSRange range = [helperOutput rangeOfString:@"<?xml"];
    if (range.location == NSNotFound) {
        BOLog(@"Helper output (missing xml): %@", helperOutput);
        if (error) {
            *error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:nil];
        }
        return NO;
    }
    
    NSString *xmlOutput = [helperOutput substringFromIndex:range.location];
    NSDictionary *helperDict = [NSPropertyListSerialization propertyListWithData:[xmlOutput dataUsingEncoding:NSUTF8StringEncoding] options:NSPropertyListImmutable format:nil error:nil];
    if (!helperDict) {
        BOLog(@"Invalid helper dictionary");
        if (error) {
            *error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:nil];
        }
        return NO;
    }
    
    NSString *blessError = helperDict[kBOHelperError];
    if (blessError) {
        BOLog(@"Invalid helper dictionary");
        if (error) {
            *error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:@{NSLocalizedDescriptionKey: blessError}];
        }
        return NO;
    }
    
    NSString *blessOutput = helperDict[kBOHelperOutput];
    const int blessStatus = [helperDict[kBOHelperStatus] intValue];
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
