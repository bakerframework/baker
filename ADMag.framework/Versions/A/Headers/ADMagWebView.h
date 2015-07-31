//
//  ADMagWebView.h
//  ADMag
//
//  Created by Dimas Gabriel on 12/9/14.
//  Copyright (c) 2014 ADMag. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MTCCDAdInsertionEntity;

/**
 *  Esta classe representa uma UIWebView responsável por renderizar e exibir os ADs (encartes) da lib ADMag.
 */
@interface ADMagWebView : UIWebView <UIWebViewDelegate>

/**
 *  Método interno que não deve ser utilizado por terceiros.
 *
 */
- (void) loadContentForAdvertising:(MTCCDAdInsertionEntity *)ad
                           success:(void (^)())success
                           failure:(void (^)(NSError *error))failure;

/**
 *  Este método deve ser chamado sempre que esta WebView ficar visível para o usuário.
 */
- (void) onShow;

/**
 *  Deve ser chamado sempre que a WebView não estiver mais visível para o usuário.
 */
- (void) onHide;

@end
