//
//  BOTaskAdditions.m
//  BootChamp
//
//  Created by Kevin Wojniak on 6/26/10.
//  Copyright 2010 Kevin Wojniak. All rights reserved.
//

#import "BOTaskAdditions.h"
#if BOAPP
#import <Security/Security.h>
#endif


@implementation NSTask (BOTaskAdditions)

#if BOAPP
+ (BOTaskReturn)launchTaskAsRootAtPath:(NSString *)path arguments:(NSArray *)arguments prompt:(NSString *)prompt output:(NSString **)output
{
    if (!path || ![[NSFileManager defaultManager] fileExistsAtPath:path]) {
		return BOTaskError;
    }
	
	AuthorizationRef authorizationRef;
	OSStatus status;
	
	status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (status != errAuthorizationSuccess) {
		return BOTaskError;
    }
	
    const char *promptUTF8 = prompt ? [prompt UTF8String] : "";
	AuthorizationItem envItems = {kAuthorizationEnvironmentPrompt, strlen(promptUTF8), (void *)promptUTF8, 0};
	AuthorizationEnvironment env = {1, &envItems};
	const char *cpath = [path fileSystemRepresentation];
	AuthorizationItem rightsItems = {kAuthorizationRightExecute, strlen(cpath), (void *)cpath, 0};
	AuthorizationRights rights = {1, &rightsItems};
	AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize;
	status = AuthorizationCopyRights(authorizationRef, &rights, &env, flags, NULL);
	if (status != errAuthorizationSuccess) {
		AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
        if (status == errAuthorizationCanceled) {
			return BOTaskAuthorizationCanceled;
        }
		return BOTaskError;
	}
	
	char **args = NULL;
	if (arguments && [arguments count] > 0) {
		args = calloc([arguments count] + 1, sizeof(char*));
        for (NSUInteger i=0; i<[arguments count]; i++) {
			args[i] = (char *)[[arguments objectAtIndex:i] UTF8String];
        }
	}
	
	FILE *file = NULL;
    // AuthorizationExecuteWithPrivileges is deprecated in 10.7, so ignore the warning for now.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	status = AuthorizationExecuteWithPrivileges(authorizationRef, cpath, kAuthorizationFlagDefaults, args, output ? &file : NULL);
#pragma clang diagnostic pop
    if (args != NULL) {
        free(args);
    }
	AuthorizationFree(authorizationRef, kAuthorizationFlagDefaults/*kAuthorizationFlagDestroyRights*/);
	if (status != errAuthorizationSuccess) {
        if (status == errAuthorizationCanceled) {
			return BOTaskAuthorizationCanceled;
        }
		return BOTaskError;
	}
	
	if (file && output) {
		NSMutableString *str = [NSMutableString string];
		char line[512];
        while (fgets(line, 512, file) != NULL) {
			[str appendFormat:@"%s", line];
        }
		*output = str;
	}
	
	return BOTaskLaunched;
}
#endif

+ (int)launchTaskAtPath:(NSString *)path arguments:(NSArray *)arguments output:(NSString **)output
{
	if ((path == nil) ||
		([[NSFileManager defaultManager] fileExistsAtPath:path] == NO) ||
		([[NSFileManager defaultManager] isExecutableFileAtPath:path] == NO)) {
		// task doesn't exist or isn't executable!
		return 1;
	}
	
	NSTask *task = [[NSTask alloc] init];
	[task setLaunchPath:path];
    if (arguments) {
		[task setArguments:arguments];
    }
	
	// NSPipe can return nil
	NSPipe *outPipe = [[NSPipe alloc] init];
    NSFileHandle *outHandle = nil;
	if (outPipe != nil) {
		outHandle = [outPipe fileHandleForReading];
		[task setStandardOutput:outPipe];
		[task setStandardError:outPipe];
	}
	
	NSPipe *inPipe = [[NSPipe alloc] init];
    NSFileHandle *inHandle = nil;
	if (inPipe != nil) {
		inHandle = [inPipe fileHandleForWriting];
		[task setStandardInput:inPipe];
	}
	
	[task launch];
	
	if (inHandle != nil) {
		NSData *inputData = nil; // dummy
		if ((inputData != nil) && ([inputData length] > 0)) {
			[inHandle writeData:inputData];
		}
		[inHandle closeFile];
	}
	
	if (outHandle != nil) {
        if (output) {
			*output = [[NSString alloc] initWithData:[outHandle readDataToEndOfFile] encoding:NSUTF8StringEncoding];
        }
		[outHandle closeFile];
	}
	
	[task waitUntilExit];
	return [task terminationStatus];
}

@end
