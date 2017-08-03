//
//  EndoNetService.m
//  EndoTest
//
//  Created by Kevin Snow on 9/28/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import "EndoAPI.h"
#import "Endo.h"
#import "EndoNetService.h"
#import "EndoCommander.h"
#import "GCDAsyncSocket.h"

@import UIKit;


@interface EndoNetService () <NSNetServiceDelegate,GCDAsyncSocketDelegate>

@property (nonatomic,strong) NSMutableArray<GCDAsyncSocket*>*   connectedSockets;
@property (nonatomic,weak)   NSObject<EndoNetServiceDelegate>*  delegate;

@property (nonatomic,strong)    NSNetService*       netService;
@property (nonatomic,strong)    dispatch_queue_t    endoQueue;

@property (nonatomic,strong)    dispatch_queue_t    socketServiceQueue;
@property (nonatomic,strong)    dispatch_queue_t    socketDelegateQueue;
@property (nonatomic,strong)    GCDAsyncSocket*     socket;

@property (nonatomic,strong)    NSString*           uuid;
@property (nonatomic,strong)    NSDictionary*       pendingInfoDict;
@property (nonatomic,assign)    NSUInteger          pendingDataLength;
@property (nonatomic,strong)    NSString*           pendingRequestId;
@property (nonatomic,strong)    NSData*             packetTailData;

@end

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

#define INIT_TAG            1555
#define PARSE_HEADER_TAG    1556
#define PARSE_INFO_TAG      1557
#define CALL_DELEGATE_TAG   1558

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

@implementation EndoNetService

    /////////////////////////////////////////////////////////////////////

#pragma mark GCDAsyncSocketDelegate

-(void)socket:(GCDAsyncSocket*)sock didAcceptNewSocket:(GCDAsyncSocket*)newSocket
{
    @synchronized(self)
    {
        [self.connectedSockets addObject:newSocket];
        newSocket.delegate = self;
        
        if( [self.delegate respondsToSelector:@selector(endoNetService:hasConnections:)] )
        {
            [self.delegate endoNetService:self hasConnections:YES];
        }
        
        dispatch_async(self.endoQueue, ^
                                        {
                                            @synchronized(self)
                                            {
                                                [self socket:newSocket didReadData:[NSData new] withTag:INIT_TAG];
                                            }
                                        });
    }
}

-(void) socketDidDisconnect:(GCDAsyncSocket*)sock withError:(NSError*)err
{
    @synchronized(self)
    {
        [self.connectedSockets removeObject:sock];
        sock.delegate = NULL;
        
        if( [self.delegate respondsToSelector:@selector(endoNetService:hasConnections:)] )
        {
            [self.delegate endoNetService:self hasConnections:(self.connectedSockets.count>0)];
        }
    }
    NSLog(@"EndoNetService: socketDidDisconnect: %@", err.description);
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

#pragma mark Data Transmition Support

-(void) sendData:(NSData*)data withInfo:(NSDictionary*)dict requestId:(NSString*)requestId
{
    @synchronized(self)
    {
        NSError* error = NULL;
        NSData* dictData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&error];
        if( !error )
        {
            NSString* packetHeader = [NSString stringWithFormat:@"<<endo ID=%@ JSON=%lu DATA=%lu /endo:%@>>",
                                                              requestId ? requestId : @"0",
                                                              (unsigned long)dictData.length,
                                                              (unsigned long)data.length,
                                                              self.uuid ];
            
            [self.connectedSockets enumerateObjectsUsingBlock:^(GCDAsyncSocket* sock, NSUInteger idx, BOOL* stop)
                                                             {
                                                                 if( sock.isConnected )
                                                                 {
                                                                     [sock writeData:[packetHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:SOCKET_TIMEOUT tag:0];
                                                                     if(dictData.length)[sock writeData:dictData withTimeout:SOCKET_TIMEOUT tag:1];
                                                                     if(data.length)[sock writeData:data withTimeout:SOCKET_TIMEOUT tag:2];
                                                                 }
                                                             }];
        }else{
            NSLog(@"Endo: error creating JSON data:%@",error.description);
        }
    }
}

    /////////////////////////////////////////////////////////////////////

-(void) socket:(GCDAsyncSocket*)sock didReadData:(NSData*)data withTag:(long)tag
{
    @synchronized(self)
    {
        NSAssert(self.packetTailData,@"bad packetTail");
        NSAssert(data || tag==INIT_TAG,@"bad data+tag");
        
        NSError*            error = nil;
        __block NSUInteger  dictionaryLen = 0;
        
        switch( tag )
        {
                    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            case PARSE_INFO_TAG:
                    //NSLog(@"PARSE_INFO_TAG");
                self.pendingInfoDict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
                if( ![self.pendingInfoDict isKindOfClass:[NSDictionary class]] )
                {
                    tag = INIT_TAG;
                    break;
                }
                if( self.pendingDataLength )
                {
                    [sock readDataToLength:self.pendingDataLength withTimeout:-1 tag:CALL_DELEGATE_TAG];
                    break;
                }
                data = nil; // No data to read, just fall through and call delegate
                
                    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            case CALL_DELEGATE_TAG:
                    //NSLog(@"CALL_DELEGATE_TAG");
                if( self.pendingInfoDict[@"command"] )
                {
                    NSString* command = self.pendingInfoDict[@"command"];
                    NSArray* parameters = self.pendingInfoDict[@"command-parameters"];
                    dispatch_async(dispatch_get_main_queue(), ^
                                   {
                                       [[EndoCommander singleton] dispatchCommand:command withParameters:parameters?parameters:@[]];
                                   });
                }
                if( self.pendingInfoDict[@"intrinsic-command"] )
                {
                    NSDictionary* dict = self.pendingInfoDict;
                    NSString* requestId = self.pendingRequestId;
                    dispatch_async(dispatch_get_main_queue(), ^
                                   {
                                           [[EndoCommander singleton] dispatchIntrinsicCommand:dict withData:data requestId:requestId];
                                   });
                }
                tag = INIT_TAG;
                break;
                
                    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            case PARSE_HEADER_TAG:
            {
                    //NSLog(@"PARSE_HEADER_TAG");
                self.pendingRequestId = @"*";
                NSArray* packetHeaderArray = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] componentsSeparatedByString:@" "];
                [packetHeaderArray enumerateObjectsUsingBlock:^(NSString* property, NSUInteger idx, BOOL* stop)
                                                             {
                                                                 if( idx == 0 )
                                                                 {
                                                                     if( ![property hasPrefix:@"<<endo"] )
                                                                     {
                                                                         *stop = YES;
                                                                         self.pendingInfoDict = nil;
                                                                         self.pendingDataLength = 0;
                                                                     }
                                                                 }else{
                                                                         // Parse the properties
                                                                     NSArray<NSString*>* propertyComponents = [property componentsSeparatedByString:@"="];
                                                                     if( propertyComponents.count == 2 )
                                                                     {
                                                                         if( [propertyComponents[0] isEqualToString:@"JSON"] )
                                                                         {
                                                                             dictionaryLen = propertyComponents[1].integerValue;
                                                                         }else
                                                                         if( [propertyComponents[0] isEqualToString:@"DATA"] )
                                                                         {
                                                                             self.pendingDataLength = propertyComponents[1].integerValue;
                                                                         }else
                                                                         if( [propertyComponents[0] isEqualToString:@"ID"] )
                                                                         {
                                                                             self.pendingRequestId = propertyComponents[1];
                                                                         }
                                                                     }
                                                                 }
                                                             }];
                if( dictionaryLen )
                {
                    [sock readDataToLength:dictionaryLen withTimeout:-1 tag:PARSE_INFO_TAG];
                }else
                if( self.pendingDataLength )
                {
                    [sock readDataToLength:self.pendingDataLength withTimeout:-1 tag:CALL_DELEGATE_TAG];
                }else{
                    tag = INIT_TAG;
                }
                break;
            }
                
                    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            case INIT_TAG:
                break;
                
                    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
            default:
                NSAssert(NO,@"bad case");
                break;
                
                    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
        }
        if( tag == INIT_TAG )
        {
            self.pendingInfoDict = nil;
            self.pendingDataLength = 0;
            [sock readDataToData:self.packetTailData withTimeout:-1 tag:PARSE_HEADER_TAG];
        }
    }
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

#pragma mark Singleton Support

-(void) startServiceWithDelegate:(NSObject<EndoNetServiceDelegate>*)delegate
{
    @synchronized(self)
    {
        if( !self.netService )
        {
            self.delegate = delegate;
            
            self.socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:self.socketDelegateQueue socketQueue:self.socketServiceQueue];
            
            dispatch_async(self.endoQueue, ^
                                                {
                                                    @synchronized(self)
                                                    {
                                                        NSError* error = NULL;
                                                        if( [self.socket acceptOnPort:0 error:&error] )
                                                        {
                                                            NSString* serviceName = [UIDevice currentDevice].name;

                                                            self.netService = [[NSNetService alloc] initWithDomain:ENDO_SERVICE_DOMAIN
                                                                                  type:ENDO_SERVICE_TYPE
                                                                                  name:serviceName.length ? serviceName : @"Endo Device"
                                                                                  port:self.socket.localPort];
                                                            self.netService.delegate = self;
                                                            [self publishService];
                                                        }else{
                                                            if( error )
                                                            {
                                                                NSLog(@"Endo: error in acceptOnPort (%@)",error.description);
                                                            }
                                                        }
                                                    }
                                                });
        }
    }
}

-(void) stopService
{
    @synchronized(self)
    {
        if( self.delegate )
        {
            [self.connectedSockets enumerateObjectsUsingBlock:^(GCDAsyncSocket* socket, NSUInteger idx, BOOL * _Nonnull stop)
                                                    {
                                                        [socket disconnect];
                                                    }];
            [self.connectedSockets removeAllObjects];
            
            [self updateTXTRecord];
            [self.netService stop];
            
            self.netService.delegate = nil;
            self.netService = nil;
            
            [self.socket disconnect];
            self.socket = nil;
            
            self.delegate = nil;
        }
    }
}

    ///////////////////////////////////////////////////////////////////////////////////////////////////////

-(void) publishService
{
    @synchronized(self)
    {
        NSLog(@"publishService");
        
        if( self.endoQueue )
        {
            dispatch_async(self.endoQueue, ^
                           {
                               @synchronized(self)
                               {
                                   [self updateTXTRecord];
                                   [self.netService publish];
                               }
                           });
        }
    }
}

-(void) unpublishService
{
    NSLog(@"unpublishService");
    
    @synchronized(self)
    {
        if( self.endoQueue )
        {
            dispatch_async(self.endoQueue, ^
                           {
                               @synchronized(self)
                               {
                                   [self.netService stop];
                               }
                           });
        }
    }
}

    ///////////////////////////////////////////////////////////////////////////////////////////////////////

-(id) init
{
    if( self = [super init] )
    {
        self.uuid = [UIDevice currentDevice].identifierForVendor.UUIDString;
        self.pendingDataLength = 0;
        self.packetTailData = [@"/endo:master>>" dataUsingEncoding:NSUTF8StringEncoding];
        self.connectedSockets = [NSMutableArray new];
        
#if 1
        self.endoQueue           = dispatch_queue_create("EndoNetService.endoQueue",            dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_USER_INTERACTIVE,0) );
        self.socketDelegateQueue = dispatch_queue_create("EndoNetService.socketDelegateQueue",  dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_USER_INTERACTIVE,0) );
        self.socketServiceQueue  = dispatch_queue_create("EndoNetService.socketDelegateQueue",  dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_USER_INTERACTIVE,0) );
#else
        self.endoQueue           = dispatch_queue_create("endo-queue", NULL);
        self.socketDelegateQueue = dispatch_queue_create("socket-delegate-queue", NULL);
        self.socketServiceQueue  = dispatch_queue_create("socket-service-queue", NULL);
#endif
    }
    
    return self;
}

+(EndoNetService*) singleton
{
    static EndoNetService* gEndoNetService = nil;
    static dispatch_once_t onceler;
    dispatch_once(&onceler, ^
                  {
                      gEndoNetService = [EndoNetService new];
                  });
    return gEndoNetService;
}

    /////////////////////////////////////////////////////////////////////

#pragma mark NSNetServiceDelegate

-(void) netServiceWillPublish:(NSNetService*)sender
{
    NSLog(@"EndoNetService: netServiceWillPublish: %@ on port %d", sender.name, self.socket.localPort);
}

- (void)netServiceWillResolve:(NSNetService*)sender
{
    NSLog(@"EndoNetService: netServiceWillResolve: %@ on port %d", sender.name, self.socket.localPort);
}

-(void) netServiceDidPublish:(NSNetService*)sender
{
    NSLog(@"EndoNetService: netServiceDidPublish: %@ on port %d", sender.name, self.socket.localPort);
}

-(void) netService:(NSNetService*)sender didNotPublish:(NSDictionary*)errorDict
{
    NSLog(@"EndoNetService: netService:didNotPublish:(%@)",errorDict);
}

-(void) netServiceDidStop:(NSNetService*)sender
{
    NSLog(@"EndoNetService: netServiceDidStop");
}

    /////////////////////////////////////////////////////////////////////

-(void) updateTXTRecord
{
    NSAssert( self.uuid, @"bad uuid in updateTXTRecord");
    
        //NSLog(@"EndoNetService: updateTXTRecord");
    
    NSString* appName = [NSBundle mainBundle].infoDictionary[@"CFBundleName"];
    
    NSDictionary* txtRecord = @{
                                @"UUID":        self.uuid,
                                @"features":    @"messages,commands,filesystem",
                                @"app-name":    appName ? appName : @"",
                                };
    
    [self.netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:txtRecord]];
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

@end
