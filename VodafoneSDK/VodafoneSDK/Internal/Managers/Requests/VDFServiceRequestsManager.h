//
//  VDFRequestsManager.h
//  HeApiIOsSdk
//
//  Created by Michał Szymańczyk on 08/07/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFBaseManager.h"
#import "VDFUsersServiceDelegate.h"
#import "VDFRequestBuilder.h"

@class VDFDIContainer, VDFCacheManager;

/**
 *  Manager of SDK requests performed from services.
 */
@interface VDFServiceRequestsManager : VDFBaseManager

/**
 *  Initialization of request manager instance.
 *
 *  @param diContainer Dependency injectionContainer.
 *  @param cacheManager Cache manager instance.
 *
 *  @return An initialized object, or nil if an object could not be created for some reason that would not result in an exception.
 */
- (instancetype)initWithDIContainer:(VDFDIContainer*)diContainer cacheManager:(VDFCacheManager*)cacheManager;

/**
 *  Method reponsible of checking cache and if needed performing new request to http/https server.
 *  On first step the cache is searched for responses of corresponding request.
 *  Next checks is there any started http/https request to the server, if exists then request is added as listener. 
 *  Requests to server are distinct so there would be only one active connection to the server for many identical requests.
 *  If request is not cached and there is no pending server connection of this request then new http/https communication to server is performed.
 *
 *  @param request Object with implemented VDFRequest protocol describing the request.
 */
- (void)performRequestWithBuilder:(id<VDFRequestBuilder>)request;

/**
 *  Remove delegate of started VDFRequest. If corresponding request is not found there nothing happens.
 *  Deleting delegate don't stops active http/https connection.
 *
 *  @param requestDelegate Delegate object which need to be unsubscribed.
 */
- (void)removeRequestObserver:(id)requestDelegate;

- (void)cancelAllPendingRequests;

@end
