//
//  VDFHttpConnectionsQueue.h
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 11/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VDFRequestBuilder.h"

@class VDFCacheManager, VDFPendingRequestItem, VDFDIContainer;

@interface VDFHttpConnectionsQueue : NSObject

- (instancetype)initWithCacheManager:(VDFCacheManager*)manager diContainer:(VDFDIContainer*)diContainer;

- (VDFPendingRequestItem*)enqueueRequestBuilder:(id<VDFRequestBuilder>)builder;

- (void)dequeueRequestItem:(VDFPendingRequestItem*)requestItem;

- (NSArray*)allPendingRequests;

@end
