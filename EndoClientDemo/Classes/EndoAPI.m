//
//  EndoAPI.m
//  EndoTest
//
//  Created by Kevin Snow on 9/25/14.
//  Copyright © 2014-2015 MynaBay. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <libkern/OSAtomic.h>
#import "EndoAPI.h"
#import "Endo.h"
#import "EndoCommander.h"

#ifndef ENDO_NO_NSLOG_OVERRIDE
    #error "ENDO_NO_NSLOG_OVERRIDE not defined"
#endif

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

static EndoExecutionState   gEndoState = EndoStateUninitialized;

static BOOL                 gEndoCPassthrough = YES;

volatile int32_t            gUncaughtExceptionCount = 0;

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void uncaughtExceptionHandler(NSException* exception)
{
    EndoLogWithCategoryStackTrace(@"UNCAUGHT", [NSString stringWithFormat:@"Exception: %@",exception.description] );
    
    [NSThread sleepForTimeInterval:2.0];
}

void SignalHandler(int signal)
{
    int32_t exceptionCount = OSAtomicIncrement32(&gUncaughtExceptionCount);
    if( exceptionCount < 10 )
    {
        NSString* sigStr;
        
        switch(signal)
        {
            case SIGABRT:
                sigStr = @"SIGABRT";
                break;
            case SIGILL:
                sigStr = @"SIGILL";
                break;
            case SIGSEGV:
                sigStr = @"SIGSEGV";
                break;
            case SIGFPE:
                sigStr = @"SIGFPE";
                break;
            case SIGBUS:
                sigStr = @"SIGBUS";
                break;
            case SIGPIPE:
                sigStr = @"SIGPIPE";
                break;
            default:
                sigStr = [NSString stringWithFormat:@"%d",signal];
            break;
        }
        
        EndoLogWithCategoryStackTrace(@"SIGNAL",[NSString stringWithFormat:@"Received signal: %@",sigStr] );
        
        [NSThread sleepForTimeInterval:2.0];
        
        exit(0);
    }
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void EndoStartStop(BOOL yesToStart_noToStop)
{
    if( gEndoState==EndoStateUninitialized || [Endo singleton].enabled!=yesToStart_noToStop )
    {
        if( yesToStart_noToStop )
        {
            gEndoState = EndoStateRunning;
            [Endo singleton].enabled = YES;
            
            NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
            signal(SIGABRT, SignalHandler);
            signal(SIGILL,  SignalHandler);
            signal(SIGSEGV, SignalHandler);
            signal(SIGFPE,  SignalHandler);
            signal(SIGBUS,  SignalHandler);
            signal(SIGPIPE, SignalHandler);
        }else{
            gEndoState = EndoStateIdle;
            [Endo singleton].enabled = NO;
            
            NSSetUncaughtExceptionHandler(nil);
            signal(SIGABRT, nil);
            signal(SIGILL,  nil);
            signal(SIGSEGV, nil);
            signal(SIGFPE,  nil);
            signal(SIGBUS,  nil);
            signal(SIGPIPE, nil);
        }
    }
}

EndoExecutionState EndoState()
{
    return gEndoState;
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////


void EndoNSLogPassthrough(BOOL yesToNSLogMessages_noToNot)
{
    if( gEndoState != EndoStateUninitialized )
    {
        if(!yesToNSLogMessages_noToNot)
        {
            EndoLogWithCategory(@"ENDO",@"Disabled NSLog passthrough");
        }
        
        [Endo singleton].passthroughToNSLog = yesToNSLogMessages_noToNot;
        
        if(yesToNSLogMessages_noToNot)
        {
            EndoLogWithCategory(@"ENDO",@"Enabled NSLog passthrough");
        }
    }
    
    gEndoCPassthrough = yesToNSLogMessages_noToNot;
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void EndoLocalLogging(BOOL yesToEnable)
{
    if( gEndoState != EndoStateUninitialized )
    {
        [Endo singleton].localLogEnable = yesToEnable;
    }
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
#ifdef VARIADIC_STYLE

void EndoLog(NSString* format, ...)
{
    va_list vargs;
    va_start(vargs,format);
    EndoLogWithCategoryVA(DEFAULT_CATEGORY,format,vargs);
    va_end(vargs);
}

    /////////////////////////////////////////////////////////////////////

void EndoLogVA(NSString* format, va_list vargs)
{
    EndoLogWithCategoryVA(DEFAULT_CATEGORY,format,vargs);
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void EndoLogWithCategory(NSString* category, NSString* format, ...)
{
    va_list vargs;
    va_start(vargs,format);
    EndoLogWithCategoryVA(category,format,vargs);
    va_end(vargs);
}

    /////////////////////////////////////////////////////////////////////

void EndoLogWithCategoryVA(NSString* category, NSString* format, va_list vargs)
{
    category = category ? category : DEFAULT_CATEGORY;
    NSString* message = [[NSString alloc] initWithFormat:format arguments:vargs];
    
    if( gEndoState == EndoStateUninitialized )
    {
        if( gEndoCPassthrough )
        {
            NSLog(@"%@ - %@",category,message);
        }
    }else{
        [[Endo singleton] logMessage:message withCategory:category];
    }
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void EndoStackTraceINTERNAL(NSArray<NSString*>* symbols, NSString* category, NSString* format, va_list vargs)
{
    NSString* message = [[NSString alloc] initWithFormat:format arguments:vargs];
    
    if( gEndoState == EndoStateUninitialized )
    {
        if( gEndoCPassthrough )
        {
            NSLog(@"%@ - %@",category,message);
            [symbols enumerateObjectsUsingBlock:^(NSString * _Nonnull symbol, NSUInteger idx, BOOL * _Nonnull stop)
                                                 {
                                                     NSLog(@"    %@",symbol);
                                                 }];
        }
    }else{
        [[Endo singleton] logMessage:message
                        withCategory:category
                      withStackTrace:symbols];
    }
}

    /////////////////////////////////////////////////////////////////////

void EndoLogStackTrace(NSString* format, ...)
{
    va_list vargs;
    va_start(vargs,format);
    EndoStackTraceINTERNAL([NSThread callStackSymbols],STACK_TRACE_CATEGORY,format,vargs);
    va_end(vargs);
}

    /////////////////////////////////////////////////////////////////////

void EndoLogStackTraceVA(NSString* format, va_list vargs)
{
    EndoStackTraceINTERNAL([NSThread callStackSymbols],STACK_TRACE_CATEGORY,format,vargs);
}

    /////////////////////////////////////////////////////////////////////

void EndoLogWithCategoryStackTrace(NSString* category, NSString* format, ...)
{
    va_list vargs;
    va_start(vargs,format);
    EndoStackTraceINTERNAL([NSThread callStackSymbols],category,format,vargs);
    va_end(vargs);
}

    /////////////////////////////////////////////////////////////////////

void EndoLogWithCategoryStackTraceVA(NSString* category, NSString* format, va_list vargs)
{
    EndoStackTraceINTERNAL([NSThread callStackSymbols],category,format,vargs);
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

#else

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void EndoLog(NSString* message)
{
    EndoLogWithCategory(DEFAULT_CATEGORY, message);
}

void EndoLogWithCategory(NSString* category, NSString* message)
{
    category = category ? category : DEFAULT_CATEGORY;
    
    if( gEndoState == EndoStateUninitialized )
    {
        if( gEndoCPassthrough )
        {
            NSLog(@"%@ - %@",category,message);
        }
    }else{
        [[Endo singleton] logMessage:message withCategory:category];
    }
}

void EndoStackTraceINTERNAL(NSArray<NSString*>* symbols, NSString* category, NSString* message)
{
    if( gEndoState == EndoStateUninitialized )
    {
        if( gEndoCPassthrough )
        {
            NSLog(@"%@ - %@",category,message);
            [symbols enumerateObjectsUsingBlock:^(NSString * _Nonnull symbol, NSUInteger idx, BOOL * _Nonnull stop)
             {
                 NSLog(@"    %@",symbol);
             }];
        }
    }else{
        [[Endo singleton] logMessage:message
                        withCategory:category
                      withStackTrace:symbols];
    }
}

void EndoLogStackTrace(NSString* message)
{
    EndoStackTraceINTERNAL([NSThread callStackSymbols],DEFAULT_CATEGORY,message);
}
void EndoLogWithCategoryStackTrace(NSString* category, NSString* message)
{
    EndoStackTraceINTERNAL([NSThread callStackSymbols],category,message);
}

#endif

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////

void EndoAddCommand(NSString* cmd, NSString* description, void (^cmdBlock)(NSArray<NSString*>*parameters))
{
    if( gEndoState != EndoStateUninitialized && cmd.length )
    {
        [[EndoCommander singleton] addCommand:cmd description:description?description:@"" withBlock:cmdBlock];
    }
}

    /////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////
