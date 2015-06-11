//
//  BKRIssueCell.m
//  Baker
//
//  ==========================================================================================
//
//  Copyright (c) 2010-2013, Davide Casali, Marco Colombo, Alessandro Morandi
//  Copyright (c) 2014, Andrew Krowczyk, Cédric Mériau, Pieter Claerhout
//  Copyright (c) 2015, Andrew Krowczyk, Cédric Mériau, Pieter Claerhout, Tobias Strebitzer
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

#import <Foundation/Foundation.h>
#import "BKRIssueCell.h"
#import "BKRSettings.h"
#import "BKRPurchasesManager.h"
#import "BKRUtils.h"

@implementation BKRIssueCell

-(id)init {
    if (self = [super init]) {
        self.issueCover.layer.shadowOpacity = 0.5;
        self.issueCover.layer.shadowOffset = CGSizeMake(0, 2);
        self.issueCover.layer.shouldRasterize = YES;
        self.issueCover.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
    return self;
}

#pragma mark - Issue management

- (IBAction)actionButtonPressed:(id)sender {
    NSString *status = [self.issue getStatus];
    if ([status isEqualToString:@"remote"] || [status isEqualToString:@"purchased"]) {
        [self.delegate issueCell:self requestsDownloadActionForIssue:self.issue];
    } else if ([status isEqualToString:@"downloaded"] || [status isEqualToString:@"bundled"]) {
        [self.delegate issueCell:self requestsReadActionForIssue:self.issue];
    } else if ([status isEqualToString:@"purchasable"]) {
        [self.delegate issueCell:self requestsPurchaseActionForIssue:self.issue];
    }
}

- (IBAction)archiveButtonPressed:(id)sender {
    UIAlertView *updateAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ARCHIVE_ALERT_TITLE", nil)
                                                          message:NSLocalizedString(@"ARCHIVE_ALERT_MESSAGE", nil)
                                                         delegate:self
                                                cancelButtonTitle:NSLocalizedString(@"ARCHIVE_ALERT_BUTTON_CANCEL", nil)
                                                otherButtonTitles:NSLocalizedString(@"ARCHIVE_ALERT_BUTTON_OK", nil), nil];
    [updateAlert show];
}


- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [self.delegate issueCell:self requestsArchiveActionForIssue:self.issue];
    }
}

#pragma mark - View management

- (void)updateView {
    [self.titleLabel setText:self.issue.title];
    [self.infoLabel setText:self.issue.info];
    
    // SETUP COVER IMAGE
    [self.issue getCoverWithCache:YES andBlock:^(UIImage *image) {
        [self.issueCover setBackgroundImage:image forState:UIControlStateNormal];
    }];
    
    NSString *status = [self.issue getStatus];
    if ([status isEqualToString:@"remote"]) {
        [self.actionButton setTitle:NSLocalizedString(@"FREE_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];
        self.actionButton.hidden  = NO;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden   = YES;
        self.loadingLabel.hidden  = YES;
    } else if ([status isEqualToString:@"connecting"]) {
        [self.spinner startAnimating];
        self.actionButton.hidden  = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.progress = 0;
        self.loadingLabel.text    = NSLocalizedString(@"CONNECTING_TEXT", nil);
        self.loadingLabel.hidden  = NO;
        self.progressBar.hidden   = YES;
    } else if ([status isEqualToString:@"downloading"]) {
        [self.spinner startAnimating];
        self.actionButton.hidden  = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.progress = 0;
        self.loadingLabel.text    = NSLocalizedString(@"DOWNLOADING_TEXT", nil);
        self.loadingLabel.hidden  = NO;
        self.progressBar.hidden   = NO;
    } else if ([status isEqualToString:@"downloaded"]) {
        [self.actionButton setTitle:NSLocalizedString(@"ACTION_DOWNLOADED_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];
        self.actionButton.hidden  = NO;
        self.archiveButton.hidden = NO;
        self.loadingLabel.hidden  = YES;
        self.progressBar.hidden   = YES;
    } else if ([status isEqualToString:@"bundled"]) {
        [self.actionButton setTitle:NSLocalizedString(@"ACTION_DOWNLOADED_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];
        self.actionButton.hidden  = NO;
        self.archiveButton.hidden = YES;
        self.loadingLabel.hidden  = YES;
        self.progressBar.hidden   = YES;
    } else if ([status isEqualToString:@"opening"]) {
        [self.spinner startAnimating];
        self.actionButton.hidden  = YES;
        self.archiveButton.hidden = YES;
        self.loadingLabel.text    = NSLocalizedString(@"OPENING_TEXT", nil);
        self.loadingLabel.hidden  = NO;
        self.progressBar.hidden   = YES;
    } else if ([status isEqualToString:@"purchasable"]) {
        [self.actionButton setTitle:self.issue.price forState:UIControlStateNormal];
        [self.spinner stopAnimating];
        self.actionButton.hidden  = NO;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden   = YES;
        self.loadingLabel.hidden  = YES;
    } else if ([status isEqualToString:@"purchasing"]) {
        [self.spinner startAnimating];
        self.loadingLabel.text = NSLocalizedString(@"BUYING_TEXT", nil);
        self.actionButton.hidden  = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden   = YES;
        self.loadingLabel.hidden  = NO;
    } else if ([status isEqualToString:@"purchased"]) {
        [self.actionButton setTitle:NSLocalizedString(@"ACTION_REMOTE_TEXT", nil) forState:UIControlStateNormal];
        [self.spinner stopAnimating];
        self.actionButton.hidden  = NO;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden   = YES;
        self.loadingLabel.hidden  = YES;
    } else if ([status isEqualToString:@"unpriced"]) {
        [self.spinner startAnimating];
        self.loadingLabel.text = NSLocalizedString(@"RETRIEVING_TEXT", nil);
        self.actionButton.hidden  = YES;
        self.archiveButton.hidden = YES;
        self.progressBar.hidden   = YES;
        self.loadingLabel.hidden  = NO;
    }
    
}

- (void)issue:(BKRIssue *)issue downloadStarted:(NSDictionary *)userInfo {
    [self updateView];
}

- (void)issue:(BKRIssue *)issue downloadProgressing:(NSDictionary *)userInfo {
    float bytesWritten = [(userInfo)[@"totalBytesWritten"] floatValue];
    float bytesExpected = [(userInfo)[@"expectedTotalBytes"] floatValue];
    if ([[self.issue getStatus] isEqualToString:@"connecting"]) {
        self.issue.status = BakerIssueStatusDownloading;
        [self updateView];
    }
    [self.progressBar setProgress:(bytesWritten / bytesExpected) animated:YES];
}

- (void)issue:(BKRIssue *)issue downloadFinished:(NSDictionary *)userInfo {
    self.issue.status = BakerIssueStatusNone;
    [self updateView];
}

- (void)issue:(BKRIssue *)issue downloadError:(NSDictionary *)userInfo {
    [BKRUtils showAlertWithTitle:NSLocalizedString(@"DOWNLOAD_FAILED_TITLE", nil)
                         message:NSLocalizedString(@"DOWNLOAD_FAILED_MESSAGE", nil)
                     buttonTitle:NSLocalizedString(@"DOWNLOAD_FAILED_CLOSE", nil)];
    self.issue.status = BakerIssueStatusNone;
    [self updateView];
}

- (void)issue:(BKRIssue *)issue unzipError:(NSDictionary *)userInfo {
    [BKRUtils showAlertWithTitle:NSLocalizedString(@"UNZIP_FAILED_TITLE", nil)
                         message:NSLocalizedString(@"UNZIP_FAILED_MESSAGE", nil)
                     buttonTitle:NSLocalizedString(@"UNZIP_FAILED_CLOSE", nil)];
    self.issue.status = BakerIssueStatusNone;
    [self updateView];
}

- (void)issue:(BKRIssue *)issue dataChanged:(NSDictionary *)userInfo {
    [self updateView];
}

@end
