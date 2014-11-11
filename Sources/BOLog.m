//
//  Created by Kevin Wojniak on 9/21/13.
//  Copyright 2013 Kevin Wojniak. All rights reserved.
//

#import "BOLog.h"

@implementation BOLog
{
    NSString *logDir_;
    NSFileManager *fm_;
    NSFileHandle *fileHandle_;
    dispatch_queue_t queue_;
}

+ (instancetype)sharedLog
{
    static BOLog *sharedLog = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLog = [[BOLog alloc] init];
    });
    return sharedLog;
}

- (id)init
{
    if ((self = [super init]) != nil)
    {
        logDir_ = [@"~/Library/Application Support/BootChamp/Logs" stringByStandardizingPath];
        fm_ = [[NSFileManager alloc] init];
        (void)[fm_ createDirectoryAtPath:logDir_ withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *logFileName = [NSString stringWithFormat:@"%@.txt", [[NSDate date] descriptionWithCalendarFormat:@"%Y%m%d%H%M%S" timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0] locale:nil]];
        NSString *logPath = [logDir_ stringByAppendingPathComponent:logFileName];
        (void)[fm_ createFileAtPath:logPath contents:nil attributes:nil];
        fileHandle_ = [NSFileHandle fileHandleForWritingAtPath:logPath];
        queue_ = dispatch_queue_create("com.kainjow.BootChamp.log", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)log:(NSString *)msg, ...
{
    NSDate *date = [NSDate date];
    va_list ap;
    va_start(ap, msg);
    NSString *fullmsg = [[NSString alloc] initWithFormat:msg arguments:ap];
    va_end(ap);
    if (![fullmsg hasSuffix:@"\n"]) {
        fullmsg = [fullmsg stringByAppendingString:@"\n"];
    }
    NSData *data = [[NSString stringWithFormat:@"%@ %@", date, fullmsg] dataUsingEncoding:NSUTF8StringEncoding];
    dispatch_async(queue_, ^{
        [fileHandle_ writeData:data];
    });
}

@end
