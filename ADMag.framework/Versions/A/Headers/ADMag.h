//
//  ADMag.h
//  ADMag
//
//  Created by Dimas Gabriel on 11/28/14.
//  Copyright (c) 2014 ADMag. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ADMagWebView.h"

/**
 *  Esta classe é responsável por todas as operações necessárias para baixar, fazer cache e exibir
 *  os ADs (encartes) de um determinado issue.
 */
@interface ADMag : NSObject

/**
 *  Este método é responsável por inicar a SDK e deve, obrigatoriamente, ser chamado antes de qualquer
 *  outro método da SDK. Você pode chamar este método no application:didFinishLaunchingWithOptions: 
 *  do seu AppDelegate.
 *
 *  @param apiKey A API Key disponibilizada para você.
 */
+ (void) startWithAPIKey:(NSString *)apiKey;

/**
 *  Este método de classe retorna uma instância compartilhada para acesso aos métodos da SDK.
 *  Sempre utilize esta instância para acessar a SDK.
 *
 *  @return Retorna uma instância da SDK, do tipo ADMag.
 */
+ (instancetype)sharedInstance;

// Publications

/**
 *  Adiciona um pubilicação. Deve ser chamado antes de fazer o cache dos ADs.
 *
 *  @param publicationId Um inteiro encapsulado em um NSNumber representando o ID de uma determinada publicação.
 */
- (void) addPublication:(NSNumber *)publicationId;

/**
 *  Adiciona um conjunto de publicações, de forma semelhante ao método addPublication:. Pode ser utilizado
 *  para adicionar mais de uma publicação ao mesmo tempo.
 *
 *  @param publicationsIds Um array de ints encapsulados em NSNumbers, cada um representando uma determinada
 *  publicação.
 */
- (void) addPublications:(NSArray *)publicationsIds;

// Issue ADs Cache

/**
 *  Este método é responsável por fazer o download e cache local dos ADs de um determinado Issue.
 *  Deve ser chamado sempre depois do addPublication e antes do adWebViewForIssueWithIdentifier:.
 *
 *  @param issueIdentifier O identificador único do Issue
 *  @param issueName       O nome do Issue
 *  @param issueCoverURL   A URL da imagem de cover do Issue
 *  @param publicationId   O ID da publicação a qual o Issue pertence
 *  @param numberOfPages   O número total de páginas do Issue
 *  @param blackList       Um array de ints, encapsuldados em NSNumbers, contendo o número de páginas que não devem receber Ads.
 *  @param pageStepBlock   Bloco chamada sempre que um AD foi baixado e inserido no cache local.
 *  @param completionBlockTotalAdsSize: Bloco chamado para informar o tamanho (em bytes) de todos os ads que serão baixados pelo SDK.  Utilizado para dar feedback ao app sobre tamanho dos arquivos a serem baixados.  
 *  @param completionBlock Bloco chamado quando todos os ADs do Issue foram baixados. cachedAdsOages é um Array de NSNumbers contendo as páginas do Issue que possuem ADs.
 */
- (void) cacheADsForIssueWithIdentifier:(NSString *)issueIdentifier
                              issueName:(NSString *)issueName
                          issueCoverURL:(NSString *)issueCoverURL
                            publication:(NSNumber *)publicationId
                          numberOfPages:(NSInteger)numberOfPages
                              blackList:(NSArray *)blackList
                          pageStepBlock:(void (^)(BOOL succeeded, NSInteger pageNumber))pageStepBlock
                        completionBlock:(void (^)(NSInteger totalAdsSize))completionBlockTotalAdsSize
                        completionBlock:(void (^)(NSArray *cachedAdsPages))completionBlock;

/**
 *
 * Apaga os ads de uma edicao. Necessario implementar no botao de delete da edicao
 */
- (void) deleteAdsForIssueWithIdentifier:(NSString *)issueIdentifier;

- (NSInteger) totalSizeAdsForDownload:(NSArray *)ads;


/**
 *  Método utilizado para consultar as páginas de um determinado issue que possuem ADs baixados e disponíveis para serem inseridos.
 *
 *  @param issueIdentifier O identificador do issue a ser consultado.
 *
 *  @return Retorna um array de ints, encapsuldados em NSNumbers, contendo as páginas que possuem ADs.
 */
- (NSArray *) pagesWithAdsForIssueIdentifier:(NSString *)issueIdentifier;


/**
 *  Método utilizado para consultar informações das paginas que receberam ADs .
 *
 *  @param issueIdentifier O identificador do issue a ser consultado.
 *
 *  @return Retorna um array de AdmagAdsInfo, contendo a página, nome da campanha e uuid da inserção que possuem ADs.
 */
- (NSArray *) infoAdsForIssueIdentifier:(NSString *)issueIdentifier;


/**
 * Este método deve ser utilizado para exibir um encarte (AD).
 *
 *  @param issueIdentifier Identificador do issue a qual o encarte sera inserido
 *  @param pageNumber      Número da página em que o encarte será inserido
 *  @param success         Bloco chamado em caso de sucesso. Este bloco contém uma webview do tipo ADMagWebView  contendo o encarte já renderizado e pronto para ser inserido. Você pode inserir este encarte utilizando addSubiview em alguma view do seu aplicativo.
 *  @param failure         Bloco chamado em caso de erro. Verifique o objeto error para mais detalhes.
 */
- (void) adWebViewForIssueWithIdentifier:(NSString *)issueIdentifier
                              pageNumber:(NSNumber *)pageNumber
                                 success:(void (^)(ADMagWebView *webview))success
                                 failure:(void (^)(NSError *error))failure;
@end
