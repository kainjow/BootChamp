//
//  Created by Kevin Wojniak on 9/21/13.
//  Copyright 2013 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BOLog : NSObject

+ (instancetype)sharedLog;

- (void)log:(NSString *)msg, ... NS_FORMAT_FUNCTION(1, 2);

@end

#define BOLog(...) [[BOLog sharedLog] log:__VA_ARGS__]
