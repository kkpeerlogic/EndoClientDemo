//
//  EndoNetService.h
//  EndoTest
//
//  Created by Kevin Snow on 9/28/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EndoAPI.h"

@class EndoNetService;

@protocol EndoNetServiceDelegate

-(void) endoNetService:(EndoNetService*)netService hasConnections:(BOOL)hasConnections;
-(void) endoNetService:(EndoNetService*)netService didReceiveData:(NSData*)data withInfo:(NSDictionary*)infoDict;

@end



@interface EndoNetService : NSObject

-(void) startServiceWithDelegate:(NSObject<EndoNetServiceDelegate>*)delegate;
-(void) stopService;

-(void) sendData:(NSData*)data withInfo:(NSDictionary*)infoDict requestId:(NSString*)requestId;

+(EndoNetService*)  singleton;

@end
