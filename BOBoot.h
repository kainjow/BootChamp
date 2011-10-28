//
//  BOBoot.h
//  BootChamp
//
//  Created by Kevin Wojniak on 7/4/07.
//  Copyright 2007-2010 Kevin Wojniak. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
	BOBootInvalidMediaError,
	BOBootAuthorizationError,
	BOBootAuthorizationCanceled,
	BOBootInstallationFailed,
	BOBootInternalError,
	BOBootRestartFailedError,
};


@class BOMedia;

BOOL BOAuthorizationRequired();
BOOL BOBoot(BOMedia *media, NSError **error);
