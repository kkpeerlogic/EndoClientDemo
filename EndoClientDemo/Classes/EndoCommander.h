//
//  EndoCommands.h
//  EndoTest
//
//  Created by Kevin Snow on 9/28/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EndoAPI.h"

@interface EndoCommander : NSObject

+(EndoCommander*) singleton;

-(void) dispatchCommand:(NSString*)cmd withParameters:(NSArray*)params;
-(void) dispatchIntrinsicCommand:(NSDictionary*)cmd withData:(NSData*)data requestId:(NSString*)requestId;

-(void) addCommand:(NSString*)cmd description:(NSString*)description withBlock:(void (^)(NSArray<NSString*>* parameters))cmdBlock;

@end
