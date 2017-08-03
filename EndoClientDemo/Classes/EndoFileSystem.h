//
//  EndoFileSystem.h
//  EndoClient
//
//  Created by Kevin Snow on 10/31/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EndoAPI.h"

@interface EndoFileSystem : NSObject

+(void) createDirectory:(NSString*)sandboxRelativePath requestId:(NSString*)requestId;
+(void) deleteDirectory:(NSString*)sandboxRelativePath requestId:(NSString*)requestId;

+(void) readFile:(NSString*)sandboxRelativePath requestId:(NSString*)requestId;
+(void) writeFile:(NSString*)sandboxRelativePath withData:(NSData*)data requestId:(NSString*)requestId;

+(void) deleteFile:(NSString*)sandboxRelativePath requestId:(NSString*)requestId;

+(void) readFileSystemWithRequestId:(NSString*)requestId;

@end
