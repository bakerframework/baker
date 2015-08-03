//
//  ShelfViewController.m
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

#import "BKRShelfViewController.h"
#import "BKRCustomNavigationBar.h"

#import "BKRBookViewController.h"
#import "BKRIssueCell.h"
#import "BKRShelfHeaderView.h"
#import "BKRSettings.h"

#import "NSData+BakerExtensions.h"
#import "NSString+BakerExtensions.h"
#import "UIScreen+BakerExtensions.h"
#import "BKRUtils.h"

#import "MBProgressHUD.h"

#import <ADMag/ADMag.h>
#import <ADMag/ADMagAdsInfo.h>

@interface BKRShelfViewController ()

@end

@implementation BKRShelfViewController

#pragma mark - Init

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        api                       = [BKRBakerAPI sharedInstance];
        issuesManager             = [BKRIssuesManager sharedInstance];
        notRecognisedTransactions = [[NSMutableArray alloc] init];
        _shelfStatus = [[BKRShelfStatus alloc] init];
        _supportedOrientation = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
        _bookToBeProcessed    = nil;
        self.automaticallyAdjustsScrollViewInsets = NO;
        if ([BKRSettings sharedSettings].isNewsstand) {
            [self configureForNewsstand];
        }else{
            [self configureWithBooks:[BKRIssuesManager localBooksList]];
        }
    }
    return self;
}

- (void)configureForNewsstand {
    purchasesManager = [BKRPurchasesManager sharedInstance];
    purchasesManager.delegate = self;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receiveBookProtocolNotification:)
                                                 name:@"notification_book_protocol"
                                               object:nil];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:purchasesManager];
}

- (void)configureWithBooks:(NSArray*)currentBooks {
    self.issues = currentBooks;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Configure navigation bar
    self.navigationItem.title = NSLocalizedString(@"SHELF_NAVIGATION_TITLE", nil);
    
    // Configure shelf layout
    [self.layout setHeaderReferenceSize:[self getBannerSize]];
    self.layout.minimumInteritemSpacing = 0;
    self.layout.minimumLineSpacing      = 0;
    
    [self.gridView registerClass:[BKRShelfHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"headerIdentifier"];
    
    NSString *backgroundFillStyle = [BKRSettings sharedSettings].issuesShelfOptions[@"backgroundFillStyle"];
    if([backgroundFillStyle isEqualToString:@"Gradient"]) {
        self.gradientLayer = [BKRUtils gradientLayerFromHexString:[BKRSettings sharedSettings].issuesShelfOptions[@"backgroundFillGradientStart"]
                                                                  toHexString:[BKRSettings sharedSettings].issuesShelfOptions[@"backgroundFillGradientStop"]];
        self.gradientLayer.frame = self.gridView.bounds;
        self.gridView.backgroundColor = [UIColor clearColor];
        self.gridView.backgroundView = [[UIView alloc] init];
        [self.gridView.backgroundView.layer insertSublayer:self.gradientLayer atIndex:0];
        self.gridView.backgroundColor = [BKRUtils colorWithHexString:[BKRSettings sharedSettings].issuesShelfOptions[@"backgroundFillColor"]];
    }else if([backgroundFillStyle isEqualToString:@"Image"]) {
        UIImage *backgroundImage = [UIImage imageNamed:@"shelf-background"];
        UIImageView *backgroundView = [[UIImageView alloc] initWithImage:backgroundImage];
        self.gridView.backgroundView = backgroundView;
    }else if([backgroundFillStyle isEqualToString:@"Pattern"]) {
        self.gridView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"shelf-background"]];
    }else if([backgroundFillStyle isEqualToString:@"Color"]) {
        self.gridView.backgroundColor = [BKRUtils colorWithHexString:[BKRSettings sharedSettings].issuesShelfOptions[@"backgroundFillColor"]];
    }

    [self.gridView reloadData];

    // Hide Buttons
    self.categoryButton.hidden = true;
    self.subscribeButton.hidden = true;
    self.refreshButton.hidden = true;
    
    if ([BKRSettings sharedSettings].isNewsstand) {
        self.refreshButton.hidden = false;
        [self.subscribeButton setTitle:NSLocalizedString(@"SUBSCRIBE_BUTTON_TEXT", nil) forState:UIControlStateNormal];
        [self.categoryButton setCategories:issuesManager.categories delegate:self];
        self.blockingProgressView = [[UIAlertView alloc]
                                     initWithTitle:@"Processing..."
                                     message:@"\n"
                                     delegate:nil
                                     cancelButtonTitle:nil
                                     otherButtonTitles:nil];
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        spinner.center = CGPointMake(139.5, 75.5); // .5 so it doesn't blur
        [self.blockingProgressView addSubview:spinner];
        [spinner startAnimating];

        NSMutableSet *subscriptions = [NSMutableSet setWithArray:[BKRSettings sharedSettings].autoRenewableSubscriptionProductIds];
        if ([[BKRSettings sharedSettings].freeSubscriptionProductId length] > 0 && ![purchasesManager isPurchased:[BKRSettings sharedSettings].freeSubscriptionProductId]) {
            [subscriptions addObject:[BKRSettings sharedSettings].freeSubscriptionProductId];
        }
        [purchasesManager retrievePricesFor:subscriptions andEnableFailureNotifications:NO];
        
        [self handleRefresh:nil];
    }
    
}

- (void)viewWillAppear:(BOOL)animated {
    [self.gridView reloadData];
    [self.gridView layoutSubviews];
    [self.layout invalidateLayout];

    if ([BKRSettings sharedSettings].isNewsstand) {

        if ([purchasesManager hasSubscriptions] || [issuesManager hasProductIDs]) {
            self.subscribeButton.hidden = false;
        }else{
            self.subscribeButton.hidden = true;
        }
        
        // Remove limbo transactions
        // take current payment queue
        SKPaymentQueue* currentQueue = [SKPaymentQueue defaultQueue];
        // finish ALL transactions in queue
        [currentQueue.transactions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [currentQueue finishTransaction:(SKPaymentTransaction*)obj];
        }];
        
        [[SKPaymentQueue defaultQueue] addTransactionObserver:purchasesManager];
    }
    
    [super viewWillAppear:animated];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self.layout invalidateLayout];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.bookToBeProcessed) {
        [self handleBookToBeProcessed];
    }
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return [self.supportedOrientation indexOfObject:[NSString bkrStringFromInterfaceOrientation:interfaceOrientation]] != NSNotFound;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

#pragma mark - Shelf data source

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView*)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView*)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.issues count];
}

- (UICollectionViewCell*)collectionView:(UICollectionView*)collectionView cellForItemAtIndexPath:(NSIndexPath*)indexPath {
    BKRIssueCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"IssueCell" forIndexPath:indexPath];
    BKRIssue *issue = self.issues[indexPath.row];
    [cell setIssue:issue];
    issue.delegate = cell;
    [cell updateView];
    return cell;
}

- (CGSize)collectionView:(UICollectionView*)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath*)indexPath {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat screenWidth = [[UIScreen mainScreen] bkrWidthForOrientation:orientation];
    int cellHeight = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 240 : 190;
    if (screenWidth > 700) {
        return CGSizeMake(screenWidth/2, cellHeight);
    } else {
        return CGSizeMake(screenWidth, cellHeight);
    }
}

- (UICollectionReusableView*)collectionView:(UICollectionView*)collectionView viewForSupplementaryElementOfKind:(NSString*)kind atIndexPath:(NSIndexPath*)indexPath {
    if (!self.headerView) {
        self.headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"headerIdentifier" forIndexPath:indexPath];
    }
    return self.headerView;
}

- (CGSize)collectionView:(UICollectionView*)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return [self getBannerSize];
}

- (IBAction)handleRefresh:(id)sender {
    [self setRefreshButtonEnabled:NO];
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hud.labelText = NSLocalizedString(@"Loading", @"");
    
    [issuesManager refresh:^(BOOL status) {
        if(status) {

            // Set dropdown categories
            self.categoryButton.categories = issuesManager.categories;
            
            // Show / Hide category button
            if(issuesManager.categories.count == 0) {
                self.categoryButton.hidden = true;
            }else{
                self.categoryButton.hidden = false;
            }

            // Set issues
            self.issues = issuesManager.issues;
            
            // Refresh issue list
            [self refreshIssueList];
            
        } else {
            [BKRUtils showAlertWithTitle:NSLocalizedString(@"INTERNET_CONNECTION_UNAVAILABLE_TITLE", nil)
                              message:NSLocalizedString(@"INTERNET_CONNECTION_UNAVAILABLE_MESSAGE", nil)
                          buttonTitle:NSLocalizedString(@"INTERNET_CONNECTION_UNAVAILABLE_CLOSE", nil)];
            
            [self setRefreshButtonEnabled:YES];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
            });
            
        }
    }];
}

- (BKRIssue*)bakerIssueWithID:(NSString*)ID {
    __block BKRIssue *foundIssue = nil;
    [self.issues enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BKRIssue *issue = (BKRIssue*)obj;
        if ([issue.ID isEqualToString:ID]) {
            foundIssue = issue;
            *stop = YES;
        }
    }];
    return foundIssue;
}

- (void)refreshIssueList {
    // Load shelf status
    [self.shelfStatus load];
    NSMutableArray *filteredIssues = [NSMutableArray array];
    
    // Prepare issues
    for (BKRIssue *issue in issuesManager.issues) {
        
        // Update prices
        issue.price = [self.shelfStatus priceFor:issue.productID];
        
        // Filter issues
        NSString *categoryButtonTitle = [self.categoryButton titleForState:UIControlStateNormal];
        if([categoryButtonTitle isEqualToString:NSLocalizedString(@"ALL_CATEGORIES_TITLE", nil)] || [issue.categories containsObject:categoryButtonTitle]) {
            [filteredIssues addObject:issue];
        }
    }
    
    // Assign filtered issues
    self.issues = [filteredIssues copy];
    
    // Update purchases
    [purchasesManager retrievePurchasesFor:[issuesManager productIDs] withCallback:^(NSDictionary *purchases) {
        [self setRefreshButtonEnabled:YES];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideAllHUDsForView:self.view animated:YES];
        });
    }];
    
    [purchasesManager retrievePricesFor:issuesManager.productIDs andEnableFailureNotifications:NO];
    
    // Prepare grid view
    [self.gridView reloadData];
    
}

#pragma mark - Store Kit
- (IBAction)handleSubscribeButtonPressed:(id)sender {
    if (self.subscriptionsActionSheet.visible) {
        [self.subscriptionsActionSheet dismissWithClickedButtonIndex:(self.subscriptionsActionSheet.numberOfButtons - 1) animated:YES];
    } else {
        self.subscriptionsActionSheet = [self buildSubscriptionsActionSheet];
        [self.subscriptionsActionSheet showFromRect:self.subscribeButton.frame inView:self.subscribeButton.superview animated:YES];
    }
}

- (UIActionSheet*)buildSubscriptionsActionSheet {
    NSString *title;
    if ([api canGetPurchasesJSON]) {
        if (purchasesManager.subscribed) {
            title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_SUBSCRIBED", nil);
        } else {
            title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_NOT_SUBSCRIBED", nil);
        }
    } else {
        title = NSLocalizedString(@"SUBSCRIPTIONS_SHEET_GENERIC", nil);
    }

    UIActionSheet *sheet = [[UIActionSheet alloc]initWithTitle:title
                                                      delegate:self
                                             cancelButtonTitle:nil
                                        destructiveButtonTitle:nil
                                             otherButtonTitles: nil];
    NSMutableArray *actions = [NSMutableArray array];

    if (!purchasesManager.subscribed) {
        if ([[BKRSettings sharedSettings].freeSubscriptionProductId length] > 0 && ![purchasesManager isPurchased:[BKRSettings sharedSettings].freeSubscriptionProductId]) {
            [sheet addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_FREE", nil)];
            [actions addObject:[BKRSettings sharedSettings].freeSubscriptionProductId];
        }

        for (NSString *productId in [BKRSettings sharedSettings].autoRenewableSubscriptionProductIds) {
            NSString *title = [purchasesManager displayTitleFor:productId];
            NSString *price = [purchasesManager priceFor:productId];
            if (price) {
                [sheet addButtonWithTitle:[NSString stringWithFormat:@"%@ %@", title, price]];
                [actions addObject:productId];
            }
        }
    }

    if ([issuesManager hasProductIDs]) {
        [sheet addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_RESTORE", nil)];
        [actions addObject:@"restore"];
    }

    [sheet addButtonWithTitle:NSLocalizedString(@"SUBSCRIPTIONS_SHEET_CLOSE", nil)];
    [actions addObject:@"cancel"];

    self.subscriptionsActionSheetActions = actions;

    sheet.cancelButtonIndex = sheet.numberOfButtons - 1;
    return sheet;
}

- (void) actionSheet:(UIActionSheet*)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet == self.subscriptionsActionSheet) {
        NSString *action = (self.subscriptionsActionSheetActions)[buttonIndex];
        if ([action isEqualToString:@"cancel"]) {
            NSLog(@"Action sheet: cancel");
            [self setSubscribeButtonEnabled:YES];
        } else if ([action isEqualToString:@"restore"]) {
            [self.blockingProgressView show];
            [purchasesManager restore];
            NSLog(@"Action sheet: restore");
        } else {
            NSLog(@"Action sheet: %@", action);
            [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerSubscriptionPurchase" object:self]; // -> Baker Analytics Event
            [self setSubscribeButtonEnabled:NO];
            if (![purchasesManager purchase:action]){
                [BKRUtils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_TITLE", nil)
                                  message:nil
                              buttonTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_CLOSE", nil)];
                [self setSubscribeButtonEnabled:YES];
            }
        }
    }
}

#pragma mark - Navigation management

- (void)collectionView:(UICollectionView*)collectionView didSelectItemAtIndexPath:(NSIndexPath*)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
}

- (void)readIssue:(BKRIssue*)issue
{
    BKRBook *book = nil;
    NSString *status = [issue getStatus];

    if ([BKRSettings sharedSettings].isNewsstand) {
        if ([status isEqual:@"opening"]) {
            book = [[BKRBook alloc] initWithBookPath:issue.path bundled:NO];
            if (book) {
                [self pushViewControllerWithIssue:issue];
            } else {
                NSLog(@"[ERROR] Book %@ could not be initialized", issue.ID);
                issue.status = BakerIssueStatusNone;
                [BKRUtils showAlertWithTitle:NSLocalizedString(@"ISSUE_OPENING_FAILED_TITLE", nil)
                                  message:NSLocalizedString(@"ISSUE_OPENING_FAILED_MESSAGE", nil)
                              buttonTitle:NSLocalizedString(@"ISSUE_OPENING_FAILED_CLOSE", nil)];
            }
        }
    } else {
        if ([status isEqual:@"bundled"]) {
            book = [issue bakerBook];
            [self pushViewControllerWithIssue:issue];
        }
    }
}

- (void)receiveBookProtocolNotification:(NSNotification*)notification {
    self.bookToBeProcessed = (notification.userInfo)[@"ID"];
    if ([self.navigationController visibleViewController] == self) {
        [self handleBookToBeProcessed];
    }else{
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}
- (void)handleBookToBeProcessed {
    BKRIssue *issue = [issuesManager issueWithId:self.bookToBeProcessed];
    if(issue) {
        NSString *status = [issue getStatus];
        if ([status isEqualToString:@"remote"] || [status isEqualToString:@"purchased"]) {
            [self issueCell:nil requestsDownloadActionForIssue:issue];
        } else if ([status isEqualToString:@"downloaded"] || [status isEqualToString:@"bundled"]) {
            [self issueCell:nil requestsReadActionForIssue:issue];
        } else if ([status isEqualToString:@"purchasable"]) {
            [self issueCell:nil requestsPurchaseActionForIssue:issue];
        }
    }
    self.bookToBeProcessed = nil;
}
- (void)pushViewControllerWithIssue:(BKRIssue*)issue {
    self.issueToBeRead = issue;
    [self performSegueWithIdentifier:@"ShowBookSegue" sender:nil];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"ShowBookSegue"]) {
        BKRBookViewController *bookViewController = [segue destinationViewController];
        [bookViewController configureWithIssue:self.issueToBeRead];
    }
}

#pragma mark - Buttons management

- (void)setRefreshButtonEnabled:(BOOL)enabled {
    self.refreshButton.enabled = enabled;
}

- (void)setSubscribeButtonEnabled:(BOOL)enabled {
    self.subscribeButton.enabled = enabled;
    if (enabled) {
        [self.subscribeButton setTitle:NSLocalizedString(@"SUBSCRIBE_BUTTON_TEXT", nil) forState:UIControlStateNormal];
    } else {
        [self.subscribeButton setTitle:NSLocalizedString(@"SUBSCRIBE_BUTTON_DISABLED_TEXT", nil) forState:UIControlStateNormal];
    }
}

- (void)webViewDidFinishLoad:(UIWebView*)webView {
    // Inject user_id
    [BKRUtils webView:webView dispatchHTMLEvent:@"init" withParams:@{@"user_id": [BKRBakerAPI UUID],
                                                                @"app_id": [BKRUtils appID]}];
}

- (IBAction)handleInfoButtonPressed:(id)sender {
    
    // If the button is pressed when the info box is open, close it
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (infoPopover.isPopoverVisible) {
            [infoPopover dismissPopoverAnimated:YES];
            return;
        }
    }
    
    // Prepare new view
    UIViewController *popoverContent = [[UIViewController alloc] init];
    UIWebView *popoverView = [[UIWebView alloc] init];
    
    popoverView.backgroundColor = [UIColor whiteColor];
    popoverView.delegate        = self;
    popoverContent.view         = popoverView;
    
    // Load HTML file
    NSString *path = [[NSBundle mainBundle] pathForResource:@"info" ofType:@"html" inDirectory:@"info"];
    [popoverView loadRequest:[NSURLRequest requestWithURL:[NSURL fileURLWithPath:path]]];
    
    // Open view
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // On iPad use the UIPopoverController
        infoPopover = [[UIPopoverController alloc] initWithContentViewController:popoverContent];
        [infoPopover presentPopoverFromRect:self.infoButton.frame inView:self.infoButton.superview permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
    } else {
        // On iPhone push the view controller to the navigation
        [self.navigationController pushViewController:popoverContent animated:YES];
    }
    
}

#pragma mark - Helper methods

- (int)getBannerHeight {
    return [[BKRSettings sharedSettings].issuesShelfOptions[[NSString stringWithFormat:@"headerHeight%@%@", [self getDeviceString], [self getOrientationString]]] intValue];
}

- (CGSize)getBannerSize {
    return CGSizeMake(self.view.frame.size.width, [self getBannerHeight]);
}

- (NSString *)getDeviceString {
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? @"Pad" : @"Phone";
}

- (NSString *)getOrientationString {
    return UIInterfaceOrientationIsLandscape(self.interfaceOrientation) ? @"Landscape" : @"Portrait";
}

#pragma mark - BKRCategoryFilterItemDelegate

- (void)categoryFilterButton:(BKRCategoryFilterButton *)categoryFilterButton clickedAction:(NSString *)action {
    [self refreshIssueList];
}

#pragma mark - BKRIssueCellDelegate

- (void)issueCell:(BKRIssueCell *)cell requestsReadActionForIssue:(BKRIssue *)issue {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerIssueOpen" object:self]; // -> Baker Analytics Event
    issue.status = BakerIssueStatusOpening;
    [self readIssue:issue];
    [cell updateView];
}

- (void)issueCell:(BKRIssueCell *)cell requestsDownloadActionForIssue:(BKRIssue *)issue {
    if ([BKRSettings sharedSettings].isNewsstand) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerIssueDownload" object:self]; // -> Baker Analytics Event
        [issue download];
        [cell updateView];
    }
}

- (void)issueCell:(BKRIssueCell *)cell requestsPurchaseActionForIssue:(BKRIssue *)issue {
    if ([BKRSettings sharedSettings].isNewsstand) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerIssuePurchase" object:self]; // -> Baker Analytics Event
        if (![[BKRPurchasesManager sharedInstance] purchase:issue.productID]) {
            // Still retrieving SKProduct: delay purchase
            issue.purchaseDelayed = true;
            [[BKRPurchasesManager sharedInstance] retrievePriceFor:issue.productID];
            issue.status = BakerIssueStatusUnpriced;
        } else {
            issue.status = BakerIssueStatusPurchasing;
        }
        [cell updateView];
    }

}

- (void)issueCell:(BKRIssueCell *)cell requestsArchiveActionForIssue:(BKRIssue *)issue {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BakerIssueArchive" object:self]; // -> Baker Analytics Event
    NKLibrary *nkLib = [NKLibrary sharedLibrary];
    NKIssue *nkIssue = [nkLib issueWithName:issue.ID];
    NSString *name   = nkIssue.name;
    NSDate *date     = nkIssue.date;
    
    //ADmag delete Ads
    BKRBook *book = [[BKRBook alloc] initWithBookPath:issue.path bundled:NO];
    [[ADMag sharedInstance] deleteAdsForIssueWithIdentifier:book.ID];
    
    [nkLib removeIssue:nkIssue];
    nkIssue = [nkLib addIssueWithName:name date:date];
    issue.path = [[nkIssue contentURL] path];
    [cell updateView];
}

#pragma mark - BKRPurchasesManagerDelegate

- (void)purchasesManager:(BKRPurchasesManager *)manager retrievedProductIds:(NSMutableSet *)productIds {
    BOOL issuesRetrieved = NO;
    NSString *price;
    for (NSString *productId in productIds) {
        if ([productId isEqualToString:[BKRSettings sharedSettings].freeSubscriptionProductId]) {
            // ID is for a free subscription
            [self setSubscribeButtonEnabled:YES];
        } else if ([[BKRSettings sharedSettings].autoRenewableSubscriptionProductIds containsObject:productId]) {
            // ID is for an auto-renewable subscription
            [self setSubscribeButtonEnabled:YES];
        } else {
            // ID is for an issue
            issuesRetrieved = YES;
            BKRIssue *issue = [issuesManager issueWithProductId:productId];
            if(issue) {
                price = [manager priceFor:issue.productID];
                [self.shelfStatus setPrice:price for:issue.productID];
                issue.price = price;
                [issue dataChanged];
            }
        }
    }
    
    if (issuesRetrieved) {
        [self.shelfStatus save];
    }
}

- (void)purchasesManager:(BKRPurchasesManager *)manager productsRequestFailedWithError:(NSError *)error {
    [BKRUtils showAlertWithTitle:NSLocalizedString(@"PRODUCTS_REQUEST_FAILED_TITLE", nil)
                         message:[error localizedDescription]
                     buttonTitle:NSLocalizedString(@"PRODUCTS_REQUEST_FAILED_CLOSE", nil)];
}

- (void)purchasesManager:(BKRPurchasesManager *)manager purchasedSubscriptionWithTransaction:(SKPaymentTransaction *)transaction {
    [manager markAsPurchased:transaction.payment.productIdentifier];
    [self setSubscribeButtonEnabled:YES];
    if ([purchasesManager finishTransaction:transaction]) {
        if (!purchasesManager.subscribed) {
            [BKRUtils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_SUCCESSFUL_TITLE", nil)
                                 message:NSLocalizedString(@"SUBSCRIPTION_SUCCESSFUL_MESSAGE", nil)
                             buttonTitle:NSLocalizedString(@"SUBSCRIPTION_SUCCESSFUL_CLOSE", nil)];
            
            [self handleRefresh:nil];
        }
    } else {
        [BKRUtils showAlertWithTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_TITLE", nil)
                             message:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_MESSAGE", nil)
                         buttonTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_CLOSE", nil)];
    }
}

- (void)purchasesManager:(BKRPurchasesManager *)manager subscriptionFailedForTransaction:(SKPaymentTransaction *)transaction {
    // Show an error, unless it was the user who cancelled the transaction
    if (transaction.error.code != SKErrorPaymentCancelled) {
        [BKRUtils showAlertWithTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_TITLE", nil)
                             message:[transaction.error localizedDescription]
                         buttonTitle:NSLocalizedString(@"SUBSCRIPTION_FAILED_CLOSE", nil)];
    }
    [self setSubscribeButtonEnabled:YES];
}

- (void)purchasesManager:(BKRPurchasesManager *)manager subscriptionRestoredForTransaction:(SKPaymentTransaction *)transaction {
    [purchasesManager markAsPurchased:transaction.payment.productIdentifier];
    if (![purchasesManager finishTransaction:transaction]) {
        NSLog(@"Could not confirm purchase restore with remote server for %@", transaction.payment.productIdentifier);
    }
}

- (void)purchasesManager:(BKRPurchasesManager *)manager productRestoredForTransaction:(SKPaymentTransaction *)transaction {
    
    // Find issue by product id
    BKRIssue *issue = [issuesManager issueWithProductId:transaction.payment.productIdentifier];
    if (issue) {
        [purchasesManager markAsPurchased:transaction.payment.productIdentifier];
        if (![purchasesManager finishTransaction:transaction]) {
            NSLog(@"[BakerShelf] Could not confirm purchase restore with remote server for %@", transaction.payment.productIdentifier);
        }
        issue.status = BakerIssueStatusNone;
        [issue dataChanged];
    }
}

- (void)purchasesManager:(BKRPurchasesManager *)manager restoreFailedWithError:(NSError *)error {
    [BKRUtils showAlertWithTitle:NSLocalizedString(@"RESTORE_FAILED_TITLE", nil)
                         message:[error localizedDescription]
                     buttonTitle:NSLocalizedString(@"RESTORE_FAILED_CLOSE", nil)];
    [self.blockingProgressView dismissWithClickedButtonIndex:0 animated:YES];
}

- (void)purchasesManager:(BKRPurchasesManager *)manager handleMultipleRestores:(NSArray *)transactions {
    if ([BKRSettings sharedSettings].isNewsstand) {
        if ([notRecognisedTransactions count] > 0) {
            NSSet *productIDs = [NSSet setWithArray:[[notRecognisedTransactions valueForKey:@"payment"] valueForKey:@"productIdentifier"]];
            NSString *productsList = [[productIDs allObjects] componentsJoinedByString:@", "];
            [BKRUtils showAlertWithTitle:NSLocalizedString(@"RESTORED_ISSUE_NOT_RECOGNISED_TITLE", nil)
                                 message:[NSString stringWithFormat:NSLocalizedString(@"RESTORED_ISSUE_NOT_RECOGNISED_MESSAGE", nil), productsList]
                             buttonTitle:NSLocalizedString(@"RESTORED_ISSUE_NOT_RECOGNISED_CLOSE", nil)];
            
            for (SKPaymentTransaction *transaction in notRecognisedTransactions) {
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            }
            [notRecognisedTransactions removeAllObjects];
        }
    }
    [self handleRefresh:nil];
    [self.blockingProgressView dismissWithClickedButtonIndex:0 animated:YES];
}

- (void)purchasesManager:(BKRPurchasesManager *)manager handleNotRecognizedTransaction:(SKPaymentTransaction *)transaction {
    [notRecognisedTransactions addObject:transaction];
}

- (void)purchasesManager:(BKRPurchasesManager *)manager purchasedProductWithTransaction:(SKPaymentTransaction *)transaction {
    
    // Find issue by product id
    BKRIssue *issue = [issuesManager issueWithProductId:transaction.payment.productIdentifier];
    if (issue) {
        [purchasesManager markAsPurchased:transaction.payment.productIdentifier];
        if ([purchasesManager finishTransaction:transaction]) {
            if (!transaction.originalTransaction) {
                // Do not show alert on restoring a transaction
                [BKRUtils showAlertWithTitle:NSLocalizedString(@"ISSUE_PURCHASE_SUCCESSFUL_TITLE", nil)
                                     message:[NSString stringWithFormat:NSLocalizedString(@"ISSUE_PURCHASE_SUCCESSFUL_MESSAGE", nil), issue.title]
                                 buttonTitle:NSLocalizedString(@"ISSUE_PURCHASE_SUCCESSFUL_CLOSE", nil)];
            }
        } else {
            [BKRUtils showAlertWithTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_TITLE", nil)
                                 message:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_MESSAGE", nil)
                             buttonTitle:NSLocalizedString(@"TRANSACTION_RECORDING_FAILED_CLOSE", nil)];
        }
        
        issue.status = BakerIssueStatusNone;
        [purchasesManager retrievePurchasesFor:[NSSet setWithObject:issue.productID] withCallback:^(NSDictionary *purchases) {
            [issue dataChanged];
        }];
    }
    
}

- (void)purchasesManager:(BKRPurchasesManager *)manager productPurchaseFailedForTransaction:(SKPaymentTransaction *)transaction {
    BKRIssue *issue = [issuesManager issueWithProductId:transaction.payment.productIdentifier];
    if (issue) {
        if (transaction.error.code != SKErrorPaymentCancelled) {
            [BKRUtils showAlertWithTitle:NSLocalizedString(@"ISSUE_PURCHASE_FAILED_TITLE", nil)
                                 message:[transaction.error localizedDescription]
                             buttonTitle:NSLocalizedString(@"ISSUE_PURCHASE_FAILED_CLOSE", nil)];
        }
        issue.status = BakerIssueStatusNone;
        [issue dataChanged];
    }
}

@end
