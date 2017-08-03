//
//  EndoCommands.m
//  EndoTest
//
//  Created by Kevin Snow on 9/28/15.
//  Copyright © 2015 MynaBay. All rights reserved.
//

#import "EndoAPI.h"
#import "Endo.h"
#import "EndoCommander.h"
#import "EndoNetService.h"
#import "EndoFileSystem.h"



@interface EndoCommander ()

@property (nonatomic,strong) NSObject*  lock;
@property (nonatomic,strong) NSMutableDictionary<NSString*,NSDictionary*>*   commands;

@end




@implementation EndoCommander

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////


-(void) dispatchIntrinsicCommand:(NSDictionary*)dict withData:(id)data requestId:(NSString*)requestId
{
    NSString* cmd = dict[@"intrinsic-command"];
    NSArray* params = dict[@"intrinsic-command-parameters"];
    
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"send-filesystem"] )
    {
        dispatch_async(dispatch_get_main_queue(), ^()
                                                    {
                                                        [EndoFileSystem readFileSystemWithRequestId:requestId];
                                                    });
    }
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"send-file"] )
    {
        if( params.count )
        {
            NSString* path = params.firstObject;
            dispatch_async(dispatch_get_main_queue(), ^()
                                                   {
                                                       [EndoFileSystem readFile:path requestId:requestId];
                                                   });
        }
    }
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"receive-file"] )
    {
        if( params.count )
        {
            NSString* path = params.firstObject;
            dispatch_async(dispatch_get_main_queue(), ^()
                                                   {
                                                       if( data && path )
                                                       {
                                                           [EndoFileSystem writeFile:path withData:data requestId:requestId];
                                                       }
                                                   });
        }
    }
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"create-directory"] )
    {
        if( params.count )
        {
            NSString* path = params.firstObject;
            dispatch_async(dispatch_get_main_queue(), ^()
                           {
                               [EndoFileSystem createDirectory:path requestId:requestId];
                           });
        }
    }
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"delete-file"] )
    {
        if( params.count )
        {
            NSString* path = params.firstObject;
            dispatch_async(dispatch_get_main_queue(), ^()
                                                   {
                                                       [EndoFileSystem deleteFile:path requestId:requestId];
                                                   });
        }
    }
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"delete-directory"] )
    {
        if( params.count )
        {
            NSString* path = params.firstObject;
            dispatch_async(dispatch_get_main_queue(), ^()
                                                   {
                                                       [EndoFileSystem deleteDirectory:path requestId:requestId];
                                                   });
        }
    }
        //////////////////////////////////////////////////////////////////
    if( [cmd isEqualToString:@"nslogging"] )
    {
        if( params.count )
        {
            NSString* enable = params.firstObject;
            if( [enable isEqualToString:@"YES"] )
            {
                EndoNSLogPassthrough(YES);
            }else
            if( [enable isEqualToString:@"NO"] )
            {
                EndoNSLogPassthrough(NO);
            }
        }
    }
        //////////////////////////////////////////////////////////////////
}

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

-(void) dispatchCommand:(NSString*)cmd withParameters:(NSArray*)params
{
        // Sanity the command
    if( cmd.length==0 || [cmd isEqualToString:@"?"] )
    {
        cmd = @"help";
    }
 
        /////////////////////////////////////////////
    @synchronized(self.lock)
    {
        NSDictionary* commandDict = self.commands[cmd];
        void (^commandBlock)(NSArray* parameters) = commandDict[@"command-block"];
        if( commandBlock )
        {
            dispatch_async(dispatch_get_main_queue(), ^()
                                                       {
                                                           commandBlock(params?params:@[]);
                                                       });
        }else{
            EndoLog([NSString stringWithFormat:@"Endo: No commandBlock for \"%@\"",cmd]);
        }
    }
}

    /////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////

-(void) addCommand:(NSString*)command description:(NSString*)description withBlock:(void (^)(NSArray<NSString*>* parameters))commandBlock
{
    if( command )
    {
        @synchronized(self.lock)
        {
            if( commandBlock )
            {
                self.commands[command] = @{ @"command-name":        command,
                                            @"command-block":       [commandBlock copy],
                                            @"command-description": description ? description : @""
                                          };
            }else{
                [self.commands removeObjectForKey:command];
            }
        }
    }
}

-(id) init
{
    if( self = [super init] )
    {
        self.lock = [NSObject new];
        self.commands = [NSMutableDictionary new];
    }
    
    return self;
}

    /////////////////////////////////////////////////////////////////////////////////////

+(EndoCommander*) singleton
{
    static EndoCommander* gEndoCommander = NULL;
    
    static dispatch_once_t onceler;
    dispatch_once(&onceler, ^
                  {
                      gEndoCommander = [EndoCommander new];
                      
                      NSString* spacerString = @"                      ";
                      
                          //////////////////////////////////////////////
                          // Add user accessible intrinsic commands
                      [gEndoCommander addCommand:@"help"
                                     description:@"Display all commands"
                                       withBlock:^(NSArray* params)
                                       {
                                           NSArray* keys = [gEndoCommander.commands.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
                                           
                                           EndoLog(@"=== Registered Endo Commands ===");
                                           [keys enumerateObjectsUsingBlock:^(NSString* command, NSUInteger idx, BOOL* stop)
                                            {
                                                if( command.length < spacerString.length )
                                                {
                                                    EndoLogWithCategory(@"ENDO",
                                                                        [NSString stringWithFormat:@"%@%@ - %@",
                                                                        [spacerString substringFromIndex:command.length],
                                                                        command,
                                                                        gEndoCommander.commands[command][@"command-description"]]);
                                                }else{
                                                    EndoLogWithCategory(@"ENDO",
                                                                        [NSString stringWithFormat:@"%@ - %@",
                                                                        command,
                                                                        gEndoCommander.commands[command][@"command-description"]]);
                                                }
                                            }];
                                       }];
                      
                      [gEndoCommander addCommand:@"endo_local_log"
                                     description:@"Enable/disable local logging (y/n)"
                                       withBlock:^(NSArray* parameters)
                                        {
                                            if( parameters.count )
                                            {
                                                if([parameters[0] isEqualToString:@"yes"]       ||
                                                   [parameters[0] isEqualToString:@"y"]         ||
                                                   [parameters[0] isEqualToString:@"enable"]    ||
                                                   [parameters[0] isEqualToString:@"1"] )
                                                {
                                                    [Endo singleton].localLogEnable = YES;
                                                }else{
                                                    [Endo singleton].localLogEnable = NO;
                                                }
                                            }else{
                                                [Endo singleton].localLogEnable = ![Endo singleton].localLogEnable;
                                            }
                                        }];
                      
                      [gEndoCommander addCommand:@"endo_nslog_passthrough"
                                     description:@"Enable/disable NSLog passthrough (y/n)"
                                       withBlock:^(NSArray* parameters)
                                       {
                                           if( parameters.count )
                                           {
                                               if([parameters[0] isEqualToString:@"yes"]       ||
                                                  [parameters[0] isEqualToString:@"y"]         ||
                                                  [parameters[0] isEqualToString:@"enable"]    ||
                                                  [parameters[0] isEqualToString:@"1"] )
                                               {
                                                   EndoNSLogPassthrough(YES);
                                               }else{
                                                   EndoNSLogPassthrough(NO);
                                               }
                                           }else{
                                               EndoNSLogPassthrough(![Endo singleton].passthroughToNSLog);
                                           }
                                       }];
                      
                      [gEndoCommander addCommand:@"userdefaults-set"
                                     description:@"userdefaults-set {key} {value}"
                                       withBlock:^(NSArray* parameters)
                                               {
                                                   if( parameters.count == 2 )
                                                   {
                                                       NSString* key = parameters[0];
                                                       NSString* value = parameters[1];
                                                       [NSUserDefaults.standardUserDefaults setObject:value
                                                                                               forKey:key];
                                                   }
                                               }];
                      
                      [gEndoCommander addCommand:@"userdefaults"
                                     description:@"userdefaults {key}"
                                       withBlock:^(NSArray* parameters)
                                           {
                                               if( parameters.count > 0 )
                                               {
                                                   [parameters enumerateObjectsUsingBlock:^(NSString*  _Nonnull key, NSUInteger idx, BOOL* _Nonnull stop)
                                                                            {
                                                                                EndoLog([NSString stringWithFormat:@"%@ = %@",key,[NSUserDefaults.standardUserDefaults objectForKey:key]] );
                                                                            }];
                                               }
                                           }];
                      
                          //////////////////////////////////////////////
                  });

    return gEndoCommander;
}

    /////////////////////////////////////////////////////////////////////////////////////

@end
