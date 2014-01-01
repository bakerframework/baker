//
//  SharePage.m
//  baker
//
//  ==========================================================================================
//
//  Copyright (c) 2010-2013
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

#import "SharePage.h"

@implementation SharePage

//  How to use
//
//  Place the following meta tags in the html page in the book. Currently the javascript searches for the first two meta tags on the html.
//   <meta content="Bring back Firefly." />
//   <meta content="http://en.wikipedia.org/wiki/Firefly_(TV_series)" />

+ (NSString *)getShareTitle:(UIWebView *)webView {
    // The javascript here returns the value of the content attribute of the 1st meta tag that appears in the html
    NSString *currentTitle = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('meta')[0].getAttribute('content');"];
    NSLog(@"Current Title: %@", [currentTitle description]);
    return currentTitle;
}

+ (NSString *)getShareURL:(UIWebView *)webView {
    // The javascript here returns the value of the content attribute of the 2nd meta tag that appears in the html
    NSString *currentURL  = [webView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('meta')[1].getAttribute('content');"];
    return currentURL;
}



@end
