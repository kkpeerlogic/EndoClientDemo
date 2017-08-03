//
//  EndoAPI.h
//  EndoClient
//
//  Created by Kevin Snow on 10/22/15.
//  Copyright © 2015-2016 MynaBay. All rights reserved.
//

#import <UIKit/UIKit.h>

    ///////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////

typedef NS_ENUM(NSInteger, EndoExecutionState) {
    EndoStateUninitialized  = 0,
    EndoStateIdle,
    EndoStateRunning,
};

    ///////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////

#if !defined(VARIADIC_STYLE) && !defined(STRING_STYLE)
    #if defined(__has_include) && __has_include(<uchar.h>)
        #define VARIADIC_STYLE
        #if defined(__cplusplus)
            #define ENDO_EXTERN extern "C"
        #else
            #define ENDO_EXTERN extern
        #endif
    #else
        #define STRING_STYLE
        #define ENDO_EXTERN
    #endif
#endif

    ///////////////////////////////////////////////////////////////////////////////////////
    // Start/Stop the Endo service
    //
    // First call to EndoStartStop will initialize EndoClient regardless of parameter value.
    // A valid configuration for shipping is to leave EndoClient in app but don't call EndoStartStop.
    // In this configuration, execution state is EndoStateUninitialized and logging is routed to NSLog.
    // Use EndoNSLogPassthrough(NO) to prevent uninitialized Endo from writing to NSLog.
    //
ENDO_EXTERN void EndoStartStop(BOOL yesToStart_noToStop);
ENDO_EXTERN EndoExecutionState EndoState();

    ///////////////////////////////////////////////////////////////////////////////////////
    // Endo logging functions.
    //
    // These functions route to NSLog if execution state is EndoStateIdle or EndoStateUninitialized.
    // The EndoNSLogPassThrough is honored regardless of the execution state.
    //
#ifdef VARIADIC_STYLE
    ENDO_EXTERN void EndoLog(NSString* format, ...);
    ENDO_EXTERN void EndoLogWithCategory(NSString* category, NSString* format, ...);

    ENDO_EXTERN void EndoLogVA(NSString* format, va_list vargs);
    ENDO_EXTERN void EndoLogWithCategoryVA(NSString* category, NSString* format, va_list vargs);
#endif
#ifdef STRING_STYLE
    void EndoLog(NSString* message);
    void EndoLogWithCategory(NSString* category, NSString* message);
#endif

void EndoLog(NSString* message);

    ///////////////////////////////////////////////////////////////////////////////////////
    // Endo functions to dump stack traces
    //
    // These functions route to NSLog if execution state is EndoStateIdle or EndoStateUninitialized.
    // The EndoNSLogPassThrough is honored regardless of the execution state.
    //
#ifdef VARIADIC_STYLE
    ENDO_EXTERN void EndoLogStackTrace(NSString* format, ...);
    ENDO_EXTERN void EndoLogWithCategoryStackTrace(NSString* category, NSString* format, ...);

    ENDO_EXTERN void EndoLogStackTraceVA(NSString* format, va_list vargs);
    ENDO_EXTERN void EndoLogWithCategoryStackTraceVA(NSString* category, NSString* format, va_list vargs);
#endif
#ifdef STRING_STYLE
    void EndoLogStackTrace(NSString* message);
    void EndoLogWithCategoryStackTrace(NSString* category, NSString* message);
#endif

    ///////////////////////////////////////////////////////////////////////////////////////
    // Endo function to add an execution block that can be called from the Endo command line.
    //
    // Add code blocks to be executed via Endo's command line.
    // Endo must be in state EndoStateRunning or EndoStateIdle when EndoAddCommand() is called.
    // Adding commands to uninitialized Endo are ignored. You can initialize Endo but not
    // publish by starting with EndoStartStop(NO).
    //
ENDO_EXTERN void EndoAddCommand(NSString* cmd, NSString* description, void (^cmdBlock)(NSArray<NSString*>*parameters));

    ///////////////////////////////////////////////////////////////////////////////////////
    // Endo enable local log
    //
    //  Write Endo logs to a unique file under Documents/ in app's sandbox. Use file system button in Endo to access log.
    //
ENDO_EXTERN void EndoLocalLogging(BOOL yesToEnable);

    ///////////////////////////////////////////////////////////////////////////////////////
    // Endo NSLog override
    //
    // Flag to control whether Endo writes to NSLog or not. Still applies on uninitialized Endo.
    //
ENDO_EXTERN void EndoNSLogPassthrough(BOOL yesToNSLogMessages_noToNot);

    ///////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////
    //
    // Our recommendation is to leave EndoClient.framework embedded and required in your application.
    // In releases aimrf at customers do not call EndoStartStop(). There is no runtime performance
    // penalty for doing this and Endo will remain uninitialized.
    //
    // When EndoClient is in an uninitialized state and all logging is routed to NSLog.
    // Log routing to NSLog can be blocked with EndoNSLogPassthrough(NO), without initializing EndoClient.
    //
    //
    // Below are macros needed when using EndoClient as an optional framework.
    // We do not recommend Endo be used in this fashion.
    // In builds where EndoClient will not be loaded ENDO_NO_NSLOG_OVERRIDE must
    // be defined OR NSLog not used.
    //

    ///////////////////////////////////////////////////////////////////////////////////////
    // Helper macro to test if EndoClient.framework was loaded. (marked optional)
    //
#define ENDO_FRAMEWORK_LOADED       (NSClassFromString(@"EndoRuntime")!=NULL)

    ///////////////////////////////////////////////////////////////////////////////////////
    // Override NSLog to route to Endo. Disable by defining ENDO_NO_NSLOG_OVERRIDE
    // Needed when used in combination with optionally loaded frameworks
    //
#ifndef ENDO_NO_NSLOG_OVERRIDE
    #ifdef NSLog
        #undef NSLog
    #endif
    #define NSLog(fmt,...)          EndoLogWithCategory(@"NSLog",fmt,##__VA_ARGS__)
#endif

    ///////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////



