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
#import <CommonCrypto/CommonDigest.h>
#import <sys/stat.h>
#import <Carbon/Carbon.h>


static NSString *const BOBootErrorDomain = @"BOBootErrorDomain";

static BOOL BORestart()
{
#if 1
    AEAddressDesc targetDesc;
    static const ProcessSerialNumber kPSNOfSystemProcess = { 0, kSystemProcess };
    AppleEvent eventReply = {typeNull, NULL};
    AppleEvent appleEventToSend = {typeNull, NULL};
    OSStatus error = noErr;
	
    error = AECreateDesc(typeProcessSerialNumber, &kPSNOfSystemProcess, sizeof(kPSNOfSystemProcess), &targetDesc);
    if (error != noErr)
        return NO;
	
    error = AECreateAppleEvent(kCoreEventClass, kAERestart, &targetDesc, kAutoGenerateReturnID, kAnyTransactionID, &appleEventToSend);
    AEDisposeDesc(&targetDesc);
    if (error != noErr)
        return NO;
	
    error = AESend(&appleEventToSend, &eventReply, kAENoReply, kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
    AEDisposeDesc(&appleEventToSend);
    if (error != noErr)
        return NO;
	
    AEDisposeDesc(&eventReply);
	return (error == noErr ? YES : NO);
#else
	return NO;
#endif
}

static NSString* BOHelperSource()
{
	static NSString *src = nil;
	if (!src) 
		src = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"BOHelper"];
	return src;
}

static NSString* BOHelperDestination()
{
	static NSString *dest = nil;
	if (!dest) {
		NSString *toolSrc = BOHelperSource();
		NSString *appSupportPath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSLocalDomainMask, YES) firstObject];
		NSString *boAppSupport = [appSupportPath stringByAppendingPathComponent:[[NSProcessInfo processInfo] processName]];
		dest = [boAppSupport stringByAppendingPathComponent:[toolSrc lastPathComponent]];
	}
	return dest;
}

static char* BOCreateMD5(const char *path)
{
	if (!path)
		return NULL;
	int f = open(path, O_RDONLY);
	if (f == -1)
		return NULL;
	unsigned char *data = calloc(1, CC_MD5_DIGEST_LENGTH * sizeof(unsigned char));
	if (!data)
		return NULL;
	char bytes[512];
	int bytes_read = 0;
	CC_MD5_CTX c;
	CC_MD5_Init(&c);
	while ((bytes_read = read(f, bytes, sizeof(bytes))) > 0)
		CC_MD5_Update(&c, bytes, bytes_read);
	close(f);
	CC_MD5_Final(data, &c);
	char *str = calloc(1, CC_MD5_DIGEST_LENGTH*2 + 1);
	for (int i=0; i<CC_MD5_DIGEST_LENGTH; i++)
		sprintf(str+(i*2), "%02X", data[i]);
	free(data);
	return str;
}	

BOOL BOAuthorizationRequired()
{
	const char *dest = [BOHelperDestination() fileSystemRepresentation];
	const char *src = [BOHelperSource() fileSystemRepresentation];
	struct stat dest_buf, src_buf;
	// verify dest exists
	if (stat(dest, &dest_buf) != 0)
		return YES;
	// verify dest's permissions
	if ((dest_buf.st_mode & TOOL_MODE) == 0)
		return YES;
	// verify dest's owner
	if (dest_buf.st_uid != 0)
		return YES;
	// verify dest and src has same size
	if (stat(src, &src_buf) != 0 || src_buf.st_size != dest_buf.st_size)
		return YES;
	// verify dest and src are equal
	int md5s_equal = 0;
	char *md5_src = BOCreateMD5(src);
	char *md5_dest = BOCreateMD5(dest);
	if (md5_src && md5_dest)
		md5s_equal = strcmp(md5_src, md5_dest) == 0;
	if (md5_src)
		free(md5_src);
	if (md5_dest)
		free(md5_dest);
	if (!md5s_equal)
		return YES;
	return NO;
}

BOOL BOBoot(BOMedia *media, NSError **error)
{
	if (!media) {
		if (error)
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInvalidMediaError userInfo:nil];
		return NO;
	}
	
	NSString *output = nil;
	BOTaskReturn ret;
	NSString *toolDest = BOHelperDestination();
	if (BOAuthorizationRequired()) {
		NSString *prompt = [NSString stringWithFormat:NSLocalizedString(@"Administrative access is needed to change your startup disk to \"%@\".", ""), media.name];
		ret = [NSTask launchTaskAsRootAtPath:[[NSBundle mainBundle] pathForAuxiliaryExecutable:@"BOHelperInstaller"] arguments:@[BOHelperSource(), toolDest] prompt:prompt output:&output];
		switch (ret) {
			case BOTaskLaunched:
				if (output && [output length] > 0) {
					if (error)
						*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInstallationFailed userInfo:@{NSLocalizedDescriptionKey : output}];
					return NO;
				}
				break;
			case BOTaskAuthorizationCanceled:
				if (error)
					*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootAuthorizationCanceled userInfo:nil];
				return NO;
			case BOTaskError:
				if (error)
					*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootAuthorizationError userInfo:output ? @{NSLocalizedDescriptionKey : output} : nil];
				return NO;
		}
	}
	
	NSMutableArray *args = [NSMutableArray array];
	if (media.deviceName) {
		[args addObject:@"-device"];
		[args addObject:media.deviceName];
	}
	else {
		[args addObject:@"-folder"];
		[args addObject:media.mountPoint];
	}
	[args addObject:@"-nextonly"];
	[args addObject:@"yes"];
	// --nextonly used to be a user-settable preference in 1.2 and previous versions,
	// but in 1.2.1 it was removed, but we keep it here for now in the app to stay
	// compatible with older versions of the helper tool so the user doesn't have to
	// reinstall it.
	
	ret = [NSTask launchTaskAtPath:toolDest arguments:args output:&output];
	switch (ret) {
		case BOTaskLaunched:
			break;
		case BOTaskError:
			if (error)
				*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:output ? @{NSLocalizedDescriptionKey : output} : nil];
			return NO;
	}
	
    if (output != nil) {
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    // ignore output if it's (seen on 10.8.1):
    // dyld: DYLD_ environment variables being ignored because main executable (/Library/Application Support/BootChamp/BOHelper) is setuid or setgid
    BOOL ignoreOutput = (output != nil && [output hasPrefix:@"dyld: DYLD_"] && [output hasSuffix:@"is setuid or setgid"]);
	if (output && [output length] > 0 && !ignoreOutput) {
		if (error)
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootInternalError userInfo:@{NSLocalizedDescriptionKey : output}];
		return NO;
	}
	
	if (!BORestart()) {
		if (error)
			*error = [NSError errorWithDomain:BOBootErrorDomain code:BOBootRestartFailedError userInfo:nil];
		return NO;
	}
	
	return YES;
}
