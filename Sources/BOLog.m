//
//  Created by Kevin Wojniak on 9/21/13.
//  Copyright 2013 Kevin Wojniak. All rights reserved.
//

#import "BOLog.h"

@implementation BOLog
{
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

- (void)removeOldLogs:(NSString *)logDir
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *logFiles = [NSMutableArray array];
    for (NSString *filename in [fm contentsOfDirectoryAtPath:logDir error:nil]) {
        if ([filename.pathExtension isEqualToString:@"txt"]) {
            NSString *fullpath = [logDir stringByAppendingPathComponent:filename];
            NSDate *fileDate = [fm attributesOfItemAtPath:fullpath error:nil].fileCreationDate;
            NSDictionary *dict = @{@"date" : fileDate, @"path" : fullpath};
            [logFiles addObject:dict];
        }
    }
    [logFiles sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"date" ascending:YES]]];
    const NSUInteger maxLogs = 5;
    while (logFiles.count > (maxLogs - 1)) {
        NSDictionary *dict = [logFiles objectAtIndex:0];
        [logFiles removeObjectAtIndex:0];
        (void)[fm removeItemAtPath:dict[@"path"] error:nil];
    }
}

- (id)init
{
    if ((self = [super init]) != nil) {
        NSString *logDir = [@"~/Library/Application Support/BootChamp/Logs" stringByStandardizingPath];
        NSFileManager *fm = [NSFileManager defaultManager];
        (void)[fm createDirectoryAtPath:logDir withIntermediateDirectories:YES attributes:nil error:nil];
        [self removeOldLogs:logDir];
        NSString *logFileName = [NSString stringWithFormat:@"%@.txt", [[NSDate date] descriptionWithCalendarFormat:@"%Y%m%d%H%M%S" timeZone:[NSTimeZone timeZoneForSecondsFromGMT:0] locale:nil]];
        NSString *logPath = [logDir stringByAppendingPathComponent:logFileName];
        (void)[fm createFileAtPath:logPath contents:nil attributes:nil];
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
