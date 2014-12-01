//
//  BOHelperClient.h
//  BootChamp
//
//  Created by Kevin Wojniak on 11/29/14.
//  Copyright 2014 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BOInstallStatus) {
    BOInstallStatusSuccess = 0,
    BOInstallStatusError = 1,
    BOInstallStatusCanceled = 2
};

BOOL BOHelperInstallationRequired(void);
BOInstallStatus BOHelperInstall(void);

int BOHelperRunTask(NSString *path, NSArray *args, NSString **output);
