//
//  EndoCommon.h
//  EndoTest
//
//  Created by Kevin Snow on 9/28/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import "EndoAPI.h"
#import "EndoNetService.h"


#define TIMESTAMP_FORMAT        @"MMM-dd HH:mm:ss.SSS"
#define DEFAULT_CATEGORY        @"EndoLog"
#define STACK_TRACE_CATEGORY    @"Stack Trace"

#define PENDING_MESSAGES_LIMIT  (250)

#define ENDO_SERVICE_DOMAIN     @"local."
#define ENDO_SERVICE_TYPE       @"_mynabay_endo._tcp."

#define SOCKET_TIMEOUT          20.0



@interface Endo : NSObject <EndoNetServiceDelegate>

+(Endo*) singleton;

@property (nonatomic,assign)    BOOL                enabled;
@property (nonatomic,assign)    BOOL                passthroughToNSLog;
@property (nonatomic,assign)    BOOL                hasConnections;

@property (nonatomic,strong)    NSObject*           lock;

@property (nonatomic,strong)    dispatch_queue_t    dispatchQueue;

@property (nonatomic,strong)    NSMutableArray<NSArray<NSString*>*>*    pendingMessages;
@property (nonatomic,strong)    NSMutableArray<NSArray<NSString*>*>*    processingMessages;

@property (nonatomic,strong)    NSDateFormatter*    dateFormatter;

@property (nonatomic,assign)    BOOL                localLogEnable;
@property (nonatomic,strong)    NSFileHandle*       localLogFile;

-(void) logMessage:(NSString*)message withCategory:(NSString*)category;
-(void) logMessage:(NSString*)message withCategory:(NSString*)category withStackTrace:(NSArray<NSString*>*)symbols;

@end
