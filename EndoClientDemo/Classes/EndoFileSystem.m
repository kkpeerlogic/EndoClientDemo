//
//  EndoFileSystem.m
//  EndoClient
//
//  Created by Kevin Snow on 10/31/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import "EndoAPI.h"
#import "Endo.h"
#import "EndoFileSystem.h"
#import "EndoNetService.h"


@interface EndoFileSystem ()

@end




@implementation EndoFileSystem

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(void) createDirectory:(NSString*)sandboxRelativePath requestId:(NSString*)requestId
{
        // Documents root
    NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString* fullPath = [paths.firstObject stringByAppendingPathComponent:sandboxRelativePath];
    
        // Create directory structure
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if( error )
    {
        [[EndoNetService singleton] sendData:nil withInfo:@{@"error":error.localizedDescription,
                                                            @"error-description":error.description} requestId:requestId];
    }else{
        [EndoFileSystem readFileSystemWithRequestId:requestId];
    }
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(void) deleteDirectory:(NSString *)sandboxRelativePath requestId:(NSString*)requestId
{
    NSMutableArray<NSString*>* pathComponents = [NSMutableArray arrayWithArray:[sandboxRelativePath pathComponents]];
    if( [pathComponents[0] isEqualToString:@"Documents"] )
    {
        [pathComponents removeObjectAtIndex:0];
        sandboxRelativePath = [NSString pathWithComponents:pathComponents];
        
        NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSString* fullPath = [paths.firstObject stringByAppendingPathComponent:sandboxRelativePath];
        NSError* error = nil;
        
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&error];
        
        if( error )
        {
            [[EndoNetService singleton] sendData:nil
                                        withInfo:@{@"error":error.localizedDescription,
                                                   @"error-description":error.description,
                                                   @"path":sandboxRelativePath}
                                       requestId:requestId];
        }else{
            [EndoFileSystem readFileSystemWithRequestId:requestId];
        }
    }
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(void) readFile:(NSString*)sandboxRelativePath requestId:(NSString*)requestId
{
    NSMutableArray<NSString*>* pathComponents = [NSMutableArray arrayWithArray:[sandboxRelativePath pathComponents]];
    if( [pathComponents[0] isEqualToString:@"Documents"] )
    {
        [pathComponents removeObjectAtIndex:0];
        sandboxRelativePath = [NSString pathWithComponents:pathComponents];
        
        NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSData* data = [NSData dataWithContentsOfFile:[paths.firstObject stringByAppendingPathComponent:sandboxRelativePath]];
        if( data )
        {
            [[EndoNetService singleton] sendData:data
                                        withInfo:@{@"receive-file":sandboxRelativePath,
                                                   @"EOF":@"YES"}
                                       requestId:requestId];
        }else{
            [[EndoNetService singleton] sendData:nil
                                        withInfo:@{@"error":@"Unable to read file",
                                                   @"error-description":@"Unable to read file",
                                                   @"path":sandboxRelativePath}
                                       requestId:requestId];
        }
    }
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(void) writeFile:(NSString*)sandboxRelativePath withData:(NSData*)data requestId:(NSString*)requestId
{
    NSArray<NSString*>* relativeComponents = [sandboxRelativePath pathComponents];
    if( [relativeComponents.firstObject isEqualToString:@"Documents"] )
    {
            // Get Documents root
        NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        __block NSString* fullPath = paths.firstObject;
        
            // Build file path minus file name (Containing directory)
        [relativeComponents enumerateObjectsUsingBlock:^(NSString* component, NSUInteger idx, BOOL* stop)
                                                 {
                                                     if( idx == relativeComponents.count-1 )    // Skip last component
                                                     {
                                                         *stop = YES;
                                                     }else{
                                                         if( idx > 0 )                          // Skip first component as it's "Documents/"
                                                         {
                                                             fullPath = [fullPath stringByAppendingPathComponent:component];
                                                         }
                                                     }
                                                 }];

            // Create directory structure
        NSError* error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:fullPath
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if( error )
        {
            [[EndoNetService singleton] sendData:nil
                                        withInfo:@{@"error":error.localizedDescription,
                                                   @"error-description":error.description,
                                                   @"path":sandboxRelativePath}
                                       requestId:requestId];
        }else{
            fullPath = [fullPath stringByAppendingPathComponent:relativeComponents.lastObject];
            if( [data writeToFile:fullPath atomically:NO] )
            {
                    // File written OK, push update FS image
                [EndoFileSystem readFileSystemWithRequestId:requestId];
            }else{
                [[EndoNetService singleton] sendData:nil
                                            withInfo:@{@"error":@"Unable to write file",
                                                       @"error-description":@"Unable to write file",
                                                       @"path":sandboxRelativePath}
                                           requestId:requestId];
            }
        }
    }else{
        [[EndoNetService singleton] sendData:nil
                                    withInfo:@{@"error":@"Bad device path",
                                               @"error-description":@"Bad device path",
                                               @"path":sandboxRelativePath}
                                   requestId:requestId];
    }
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(void) deleteFile:(NSString*)sandboxRelativePath requestId:(NSString*)requestId
{
    NSMutableArray<NSString*>* pathComponents = [NSMutableArray arrayWithArray:[sandboxRelativePath pathComponents]];
    if( [pathComponents[0] isEqualToString:@"Documents"] )
    {
        [pathComponents removeObjectAtIndex:0];
        sandboxRelativePath = [NSString pathWithComponents:pathComponents];
        
        NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        NSString* fullPath = [paths.firstObject stringByAppendingPathComponent:sandboxRelativePath];
        NSError* error = nil;
        
        [[NSFileManager defaultManager] removeItemAtPath:fullPath error:&error];
        
        if( error )
        {
            [[EndoNetService singleton] sendData:nil
                                        withInfo:@{@"error":error.localizedDescription,
                                                   @"error-description":error.description}
                                       requestId:requestId];
        }else{
            [EndoFileSystem readFileSystemWithRequestId:requestId];
        }
    }
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(NSDictionary*) contentsForURL:(NSURL*)urlParam withPath:(NSString*)fsPath;
{
    
    NSDirectoryEnumerator* enumerator = [[NSFileManager defaultManager]
                                         enumeratorAtURL:urlParam
                                         includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey,NSURLNameKey,NSURLFileSizeKey,nil]
                                         options:NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                         errorHandler:^(NSURL* url, NSError* error)
                                                             {
                                                                 return YES;
                                                             }];
    
    NSMutableDictionary* mDict = [NSMutableDictionary new];
    
    for (NSURL* url in enumerator)
    {
        NSError*  error = nil;
        NSNumber* isDirectory = nil;
        NSString* name = nil;
        NSNumber* size = nil;
        
        [url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
        
        if( [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error] )
        {
            if( [url getResourceValue:&name forKey:NSURLNameKey error:&error] )
            {
                NSString* myPath = [fsPath stringByAppendingPathComponent:name];
                if( isDirectory.boolValue )
                {
                    [mDict setObject:@{@"contents":[self contentsForURL:url withPath:myPath],
                                       @"path":myPath,
                                       @"name":name,
                                       @"type":@"directory"}
                              forKey:name];
                }else{
                    [mDict setObject:@{@"path":myPath,
                                       @"name":name,
                                       @"type":@"file",
                                       @"size":size}
                              forKey:name];
                }
            }
        }
    }
    
    return mDict;
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+(void) readFileSystemWithRequestId:(NSString*)requestId
{
    NSArray<NSString*>* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSDictionary* documentsDir= @{@"contents":[EndoFileSystem contentsForURL:[NSURL URLWithString:paths.firstObject] withPath:@"Documents"],
                                  @"path":@"Documents",
                                  @"name":@"Documents",
                                  @"type":@"directory"
                                 };
    NSDictionary* fsDict = @{@"contents":@{@"Documents":documentsDir},
                             @"type":@"directory"
                            };
    [[EndoNetService singleton] sendData:nil withInfo:@{@"receive-filesystem":fsDict} requestId:requestId];
}

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@end
