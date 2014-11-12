/*
 *  Created by Kevin Wojniak on 9/5/08.
 *  Copyright 2008-2014 Kevin Wojniak. All rights reserved.
 */

#import "BOTaskAdditions.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
	if (geteuid() != 0) {
		fprintf(stdout, "Must be run as root.\n");
		return EXIT_FAILURE;
	}
	
	if (argc < 5) {
		fprintf(stdout, "Invalid number of arguments.\n");
		return EXIT_FAILURE;
	}
	
	if ((strcmp(argv[1], "-device") && strcmp(argv[1], "-folder")) || strcmp(argv[3], "-nextonly") || (strcmp(argv[4], "yes") && strcmp(argv[4], "no"))) {
		fprintf(stdout, "Bad arguments.\n");
		return EXIT_FAILURE;
	}
	
	char *media_arg = argv[1];
	char *media_val = argv[2];
	char *nextonly = argv[4];
    NSMutableArray *args = [NSMutableArray array];
    if (strcmp(nextonly, "yes") == 0) {
        [args addObject:@"--nextonly"];
    }
    [args addObject:@"--verbose"];
    [args addObject:@"--legacy"];
    [args addObject:@"--setBoot"];
    [args addObject:strcmp(media_arg, "-device") == 0 ? @"--device" : @"--mount"];
        [args addObject:[NSString stringWithUTF8String:media_val]];
	
    NSString *output = nil;
    int status = [NSTask launchTaskAtPath:@"/usr/sbin/bless" arguments:args output:&output];
    if (output) {
        output = [output stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    if (status != 0) {
        fprintf(stdout, "%s\n", [output UTF8String]);
		fprintf(stdout, "Bless failed\n");
		return EXIT_FAILURE;
	}
	
    return EXIT_SUCCESS;
    }
}
