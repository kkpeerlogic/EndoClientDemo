//
//  EndoInternal.m
//  EndoTest
//
//  Created by Kevin Snow on 9/25/14.
//  Copyright © 2014-2015 MynaBay. All rights reserved.
//

#import "EndoAPI.h"
#import "Endo.h"
#import "EndoNetService.h"
#import "EndoCommander.h"

#import <UIKit/UIKit.h>
@interface Endo()
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@end
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

@implementation Endo

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

#pragma mark EndoNetServiceDelegate

-(void) endoNetService:(EndoNetService*)netService hasConnections:(BOOL)hasConnections
{
    @synchronized(self.lock)
    {
        self.hasConnections = hasConnections;
        if( hasConnections )
        {
            dispatch_async(dispatch_get_main_queue(), ^
                            {
                                [self messageDispatch];
                            });
        }
    }
}

-(void) endoNetService:(EndoNetService*)netService didReceiveData:(NSData*)data withInfo:(NSDictionary*)infoDict
{
    NSString* command = infoDict[@"command"];
    if( [command isKindOfClass:[NSString class]] )
    {
        NSArray* parameters = infoDict[@"command-parameters"];
        [[EndoCommander singleton] dispatchCommand:command
                                    withParameters:[parameters isKindOfClass:[NSArray class]] ? parameters : @[]];
    }
}

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

#pragma mark Logging Support

-(void) logMessage:(NSString*)message withCategory:(NSString*)category
{
    @synchronized(self.lock)
    {
        if( !self.hasConnections || self.passthroughToNSLog || !self.enabled )
        {
            NSLog(@"%@",message);
        }
    
        if( self.enabled )
        {
            NSArray<NSString*>* messageArray = @[ [self.dateFormatter stringFromDate:[NSDate date]],
                                                  category?category:DEFAULT_CATEGORY,
                                                  message?message:@""];
            
            [self.pendingMessages addObject:messageArray];
            [self messageDispatch];
            
            if( self.localLogFile )
            {
                NSString* textToWrite = [NSString stringWithFormat:@"%@ - %@ - %@\n",messageArray[0],messageArray[1],messageArray[2]];
                [self.localLogFile writeData:[textToWrite dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
}

    /////////////////////////////////////////////////////////////////////////////////

-(void) logMessage:(NSString*)message withCategory:(NSString*)category withStackTrace:(NSArray<NSString*>*)symbols
{
    @synchronized(self.lock)
    {
        if( !self.hasConnections || self.passthroughToNSLog || !self.enabled )
        {
            NSLog(@"%@",message);
            [symbols enumerateObjectsUsingBlock:^(NSString * _Nonnull symbol, NSUInteger idx, BOOL * _Nonnull stop)
                                                     {
                                                         NSLog(@"     %@",symbol);
                                                     }];
        }
        
        if( self.enabled )
        {
            NSArray<NSString*>* messageArray = @[ [self.dateFormatter stringFromDate:[NSDate date]],
                                                  category?category:DEFAULT_CATEGORY,
                                                  message?message:@""];
            [self.pendingMessages addObject:messageArray];
            [symbols enumerateObjectsUsingBlock:^(NSString* symbol, NSUInteger idx, BOOL* stop)
                                         {
                                             [self.pendingMessages addObject:@[@"",@"",symbol]];
                                         }];
            [self messageDispatch];
            
            if( self.localLogFile )
            {
                NSMutableString* stackTrace = [NSMutableString new];
                [symbols enumerateObjectsUsingBlock:^(NSString* symbol, NSUInteger idx, BOOL* stop)
                                                     {
                                                         [stackTrace appendString:[NSString stringWithFormat:@"        %@\n",symbol]];
                                                     }];
                NSString* textToWrite = [NSString stringWithFormat:@"%@ - %@ - %@\n",messageArray[0],messageArray[1],messageArray[2]];
                [self.localLogFile writeData:[textToWrite dataUsingEncoding:NSUTF8StringEncoding]];
                [self.localLogFile writeData:[stackTrace dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
}

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

-(void) messageDispatch
{
    @synchronized(self.lock)
    {
            // Limit pending queue length
        if( self.pendingMessages.count > PENDING_MESSAGES_LIMIT )
        {
            [self.pendingMessages removeObjectsInRange:NSMakeRange(0,self.pendingMessages.count-PENDING_MESSAGES_LIMIT)];
        }
        
            // If not processing any message and there are some pending processing, queue them up!
        if( self.hasConnections && self.processingMessages.count==0 && self.pendingMessages.count )
        {
                // Swap pending and processing queues
            NSMutableArray* temp = self.pendingMessages;
            self.pendingMessages = self.processingMessages;
            self.processingMessages = temp;
        
                // Dispatch job to send the messages
            dispatch_async( self.dispatchQueue, ^()
                                       {
                                           @autoreleasepool
                                           {
                                               [[EndoNetService singleton] sendData:nil withInfo:@{@"messages":self.processingMessages} requestId:@"0"];
                                           }
                                           @synchronized(self.lock)
                                           {
                                               [self.processingMessages removeAllObjects];
                                               [self messageDispatch];
                                           }
                                       });
        }
    }
}

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

-(void) openLocalLog
{
    if( !self.localLogFile )
    {
        NSError* error = nil;
        
        static NSDateFormatter* formatter = NULL;
        if( !formatter )
        {
            formatter = [NSDateFormatter new];
            [formatter setDateFormat:@"LLL_d_YYYY__HHmmss"];
        }
        
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* filePath = [paths[0] stringByAppendingPathComponent:@"__endo__"];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:filePath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if( !error )
        {
            filePath = [filePath stringByAppendingPathComponent:[formatter stringFromDate:[NSDate date]]];
            filePath = [filePath stringByAppendingPathExtension:@"log"];
        
            [[NSFileManager defaultManager] createFileAtPath:filePath contents:NULL attributes:NULL];
            
            EndoLogWithCategory(@"ENDO",[NSString stringWithFormat:@"Started local log: %@",filePath]);
            
            self.localLogFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
        }else{
            EndoLogWithCategory(@"ENDO",[NSString stringWithFormat:@"Error starting local logging: %@",error.description]);
        }
    }
}

-(void) closeLocalLog
{
    if( self.localLogFile )
    {
        EndoLogWithCategory(@"ENDO",@"Closed local log");
        
        [self.localLogFile closeFile];
        self.localLogFile = NULL;
    }
}

    /////////////////////////////////////////////////////////////////////////////////

-(BOOL) localLogEnable
{
    @synchronized(self.lock)
    {
        return (self.localLogFile != NULL);
    }
}

-(void) setLocalLogEnable:(BOOL)localLogEnable
{
    @synchronized(self.lock)
    {
        if( localLogEnable && self.localLogFile )
        {
            EndoLogWithCategory(@"ENDO",@"Local logging already setup");
        }else
            
        if( localLogEnable && !self.localLogFile )
        {
            [self openLocalLog];
        }else
            
        if( !localLogEnable && !self.localLogFile )
        {
            EndoLogWithCategory(@"ENDO",@"Local logging not setup");
        }else
            
        if( !localLogEnable && self.localLogFile )
        {
            [self closeLocalLog];
        }
    }
}

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

#pragma mark Singleton Support

-(id) init
{
    if( self = [super init] )
    {
        self.lock = [NSObject new];
        self.dateFormatter = [NSDateFormatter new];
        self.dateFormatter.dateFormat = TIMESTAMP_FORMAT;
        self.pendingMessages = [NSMutableArray new];
        self.processingMessages = [NSMutableArray new];
        self.passthroughToNSLog = NO;
        
            //self.dispatchQueue = dispatch_queue_create("endo-dispatch-queue", NULL);
        self.dispatchQueue = dispatch_queue_create("endo-dispatch-queue",dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_USER_INTERACTIVE,0));
      
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(applicationWillResign:)       name:UIApplicationWillResignActiveNotification object:NULL];
        [nc addObserver:self selector:@selector(applicationWillBecomeActive:) name:UIApplicationDidBecomeActiveNotification  object:NULL];
        [self setupBackgrounding];
        [self keepAlive];
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

    /////////////////////////////////////////////////////////////////////////////////

+(Endo*) singleton
{
    static Endo* gEndo = nil;
    static dispatch_once_t onceler;
    dispatch_once(&onceler, ^
                  {
                      gEndo = [Endo new];
                      [EndoCommander singleton];
                  });
    return gEndo;
}

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

-(void) applicationWillResign:(NSNotification*)notification
{
    self.hasConnections = YES;
    [[EndoNetService singleton] startServiceWithDelegate:self];
}

-(void) applicationWillBecomeActive:(NSNotification*)notification
{
    if( self.enabled )
    {
        [[EndoNetService singleton] startServiceWithDelegate:self];
    }
}

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

-(void) setEnabled:(BOOL)enabled
{
    @synchronized(self.lock)
    {
        if( enabled != _enabled )
        {
            if( enabled )
            {
                [[EndoNetService singleton] startServiceWithDelegate:self];
                _enabled = YES;
                [self logMessage:@"Endo Started" withCategory:@"ENDO"];
            }else{
                [[EndoNetService singleton] stopService];
                _enabled = NO;
            }
        }
    }
}

- (void)setupBackgrounding {
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(appBackgrounding:)
                                                 name: UIApplicationDidEnterBackgroundNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(appForegrounding:)
                                                 name: UIApplicationWillEnterForegroundNotification
                                               object: nil];
}

- (void)appBackgrounding: (NSNotification *)notification {
    [self keepAlive];
}

- (void) keepAlive {
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
        [self keepAlive];
    }];
}

- (void)appForegrounding: (NSNotification *)notification {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

@interface EndoRuntime : NSObject
@end

@implementation EndoRuntime
@end

    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////

