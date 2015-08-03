//
//  BakerAnalyticsEvents.m
//  Baker
//
//  ==========================================================================================
//
//  Copyright (c) 2010-2013, Davide Casali, Marco Colombo, Alessandro Morandi
//  Copyright (c) 2014, Andrew Krowczyk, Cédric Mériau, Pieter Claerhout
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are
//  permitted provided that the following conditions are met:
//
//  Redistributions of source code must retain the above copyright notice, this list of
//  conditions and the following disclaimer.
//  Redistributions in binary form must reproduce the above copyright notice, this list of
//  conditions and the following disclaimer in the documentation and/or other materials
//  provided with the distribution.
//  Neither the name of the Baker Framework nor the names of its contributors may be used to
//  endorse or promote products derived from this software without specific prior written
//  permission.
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "BKRAnalyticsEvents.h"
#import "BKRSettings.h"
#import <ADMag/GAI.h>
#import <ADMag/GAIDictionaryBuilder.h>
#import "BKRBookViewController.h"

@implementation BKRAnalyticsEvents

#pragma mark - Singleton

+ (BKRAnalyticsEvents *)sharedInstance {
    static dispatch_once_t once;
    static BKRAnalyticsEvents *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
    
        // ****** Add here your analytics code
        
        //GAI Configuration
        // Optional: automatically send uncaught exceptions to Google Analytics.
        [GAI sharedInstance].trackUncaughtExceptions = YES;
        
        // Optional: set Google Analytics dispatch interval to e.g. 20 seconds.
        [GAI sharedInstance].dispatchInterval = 20;
        
        // Optional: set Logger to VERBOSE for debug information.
        //[[[GAI sharedInstance] logger] setLogLevel:kGAILogLevelVerbose];
        
        // Initialize tracker. Replace with your tracking ID.
        [[GAI sharedInstance] trackerWithTrackingId:[BKRSettings sharedSettings].googleAnalyticsID];
        
        // ****** Register to handle events
        [self registerEvents];

    }
    return self;
}

- (void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Events

- (void)registerEvents {

    // Register the analytics event that are going to be tracked by Baker.
    NSArray *analyticEvents = @[@"BakerApplicationStart",
                               @"BakerIssueDownload",
                               @"BakerIssueOpen",
                               @"BakerIssueClose",
                               @"BakerIssuePurchase",
                               @"BakerIssueArchive",
                               @"BakerSubscriptionPurchase",
                               @"BakerViewPage",
                               @"BakerViewIndexOpen",
                               @"BakerViewModalBrowser"];
    
    for (NSString *eventName in analyticEvents) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(receiveEvent:)
                                                     name:eventName
                                                   object:nil];
    }
    
}

- (void)receiveEvent:(NSNotification*)notification {
    //NSLog(@"[BakerAnalyticsEvent] Received event %@", notification.name); // Uncomment this to debug
    //GAI Activation
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    
    // If you want, you can handle differently the various events
    if ([notification.name isEqualToString:@"BakerApplicationStart"]) {
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"ui_action"     // Event category (required)
                                                              action:@"open"  // Event action (required)
                                                               label:@"Baker App Open"          // Event label
                                                               value:nil] build]];    // Event value
    } else if ([notification.name isEqualToString:@"BakerIssueDownload"]) {
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"ui_action"     // Event category (required)
                                                              action:@"download"  // Event action (required)
                                                               label:@"Baker Issue Download"          // Event label
                                                               value:nil] build]];    // Event value
    } else if ([notification.name isEqualToString:@"BakerIssueOpen"]) {
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"ui_action"     // Event category (required)
                                                              action:@"open"  // Event action (required)
                                                               label:@"Baker Issue Open"          // Event label
                                                               value:nil] build]];    // Event value
    } else if ([notification.name isEqualToString:@"BakerIssueClose"]) {
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"ui_action"     // Event category (required)
                                                              action:@"open"  // Event action (required)
                                                               label:@"Baker Issue Close"          // Event label
                                                               value:nil] build]];    // Event value
    } else if ([notification.name isEqualToString:@"BakerIssuePurchase"]) {
        // Track here when a issue purchase is requested
    } else if ([notification.name isEqualToString:@"BakerIssueArchive"]) {
        [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"ui_action"     // Event category (required)
                                                              action:@"open"  // Event action (required)
                                                               label:@"Baker Issue Archive"          // Event label
                                                               value:nil] build]];    // Event value
    } else if ([notification.name isEqualToString:@"BakerSubscriptionPurchase"]) {
        // Track here when a subscription purchased is requested
    } else if ([notification.name isEqualToString:@"BakerViewPage"]) {
        // Track here when a specific page is opened
    } else if ([notification.name isEqualToString:@"BakerViewIndexOpen"]) {
        // Track here the opening of the index and status bar
    } else if ([notification.name isEqualToString:@"BakerViewModalBrowser"]) {
        // Track here the opening of the modal view
    } else {
    }

}

@end
