//
//  BOTaskAdditions.h
//  BootChamp
//
//  Created by Kevin Wojniak on 6/26/10.
//  Copyright 2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>


#if BOAPP
enum {
	BOTaskLaunched,
	BOTaskAuthorizationCanceled,
	BOTaskError,
};
typedef NSInteger BOTaskReturn;
#endif


@interface NSTask (BOTaskAdditions)

#if BOAPP
+ (BOTaskReturn)launchTaskAsRootAtPath:(NSString *)path arguments:(NSArray *)arguments prompt:(NSString *)prompt output:(NSString **)output;
#endif
+ (int)launchTaskAtPath:(NSString *)path arguments:(NSArray *)arguments output:(NSString **)output;

@end
