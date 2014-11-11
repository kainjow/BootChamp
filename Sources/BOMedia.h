//
//  BOMedia.h
//  BootChamp
//
//  Created by Kevin Wojniak on 9/9/08.
//  Copyright 2008-2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DiskArbitration/DiskArbitration.h>

@interface BOMedia : NSObject

+ (NSArray *)allMedia;

@property (strong) NSString *mountPoint;
@property (strong) NSString *deviceName;
@property (strong) NSString *name;

+ (DASessionRef)session;

@end
