//
//  BOMedia.h
//  BootChamp
//
//  Created by Kevin Wojniak on 9/9/08.
//  Copyright 2008-2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface BOMedia : NSObject
{
	NSString *mountPoint_;
	NSString *deviceName_;
	NSString *name_;
}

+ (NSArray *)allMedia;

@property (readwrite, retain) NSString *mountPoint;
@property (readwrite, retain) NSString *deviceName;
@property (readwrite, retain) NSString *name;

@end
