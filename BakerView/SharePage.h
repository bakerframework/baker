//
//  SharePage.h
//  thesaturdaypaper
//
//  Created by Owen Kelly on 20/12/2013.
//
//

#import <Foundation/Foundation.h>

@interface SharePage : NSObject

+ (NSString *)getShareTitle:(UIWebView *)webView;
+ (NSString *)getShareURL:(UIWebView *)webView;


@end
