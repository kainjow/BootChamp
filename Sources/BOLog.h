//
//  Created by Kevin Wojniak on 9/21/13.
//  Copyright 2013 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BOLog : NSObject

+ (instancetype)sharedLog;

- (void)log:(NSString *)msg, ...;

@end

#define BOLog(fmt, ...) [[BOLog sharedLog] log:fmt, __VA_ARGS__]
