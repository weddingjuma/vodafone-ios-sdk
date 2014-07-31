//
//  VDFRequestsManager.m
//  HeApiIOsSdk
//
//  Created by Michał Szymańczyk on 08/07/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFServiceRequestsManager.h"
#import "VDFBaseConfiguration.h"
#import "VDFHttpConnector.h"
#import "VDFSettings+Internal.h"
#import "VDFCacheManager.h"
#import "VDFEnums.h"
#import "VDFNetworkReachability.h"
#import "VDFError.h"
#import "VDFLogUtility.h"

#pragma mark VDFPendingRequestHolder class

@interface VDFPendingRequestHolder : NSObject

// request which started the http request
@property (nonatomic, strong) id<VDFRequest> initialRequest;
// pending http request to the server
@property (nonatomic, strong) VDFHttpConnector *httpRequest;
// list of all requests waiting for the response
@property (nonatomic, strong) NSMutableArray *waitingRequests;
// number of all http requests made for this holder
@property (nonatomic, assign) NSInteger numberOfRetries;

@end

@implementation VDFPendingRequestHolder

- (instancetype)init {
    self = [super init];
    if(self) {
        self.waitingRequests = [[NSMutableArray alloc] init];
        self.numberOfRetries = 0;
    }
    return self;
}

@end

#pragma mark - VDFServiceRequestsManager class

@interface VDFServiceRequestsManager ()
@property (nonatomic, strong) VDFBaseConfiguration *configuration;
// array of VDFPendingRequestHolder objects
@property (nonatomic) NSMutableArray *pendingRequests;

- (void)retryRequest:(VDFPendingRequestHolder*)requestHolder;
- (void)startHttpRequest:(VDFPendingRequestHolder*)requestHolder;
- (void)stopRequest:(VDFPendingRequestHolder*)requestHolder withDomainErrorCode:(VDFErrorCode)errorCode;

@end

@implementation VDFServiceRequestsManager

- (instancetype)initWithConfiguration:(VDFBaseConfiguration*)configuration {
    self = [super init];
    if(self) {
        VDFLogD(@"Initializing Service Request Manager");
        self.configuration = configuration;
        self.pendingRequests = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)performRequest:(id<VDFRequest>)request {
    id<NSCoding> responseObject = nil;
    VDFPendingRequestHolder *requestHolder = nil;
    
    @synchronized(self.pendingRequests) {
        
        // check cache:
        if([request isCachable] && [[VDFSettings sharedCacheManager] isResponseCachedForRequest:request]) {
            // our object is cached so we read cache:
            VDFLogD(@"Response Object is cached, so we read this from cache.");
            responseObject = [[VDFSettings sharedCacheManager] responseForRequest:request];
        }
        else {
            VDFLogD(@"Response Object is not cached, so we need to perform http request.");
            BOOL subscribedForResponse = NO;
            
            // check is there any the same request waiting for response
            for (VDFPendingRequestHolder *pendingRequestHolder in self.pendingRequests) {
                if([pendingRequestHolder.initialRequest isEqualToRequest:request]) {
                    subscribedForResponse = YES;
                    // subscribe for response
                    [pendingRequestHolder.waitingRequests addObject:request];
                    VDFLogD(@"Http communication is started for this request, registering this request as observer.");
                    break;
                }
            }
            
            if(!subscribedForResponse) {
                // creating new request
                VDFHttpConnector * httpRequest = [[VDFHttpConnector alloc] initWithDelegate:self];
                httpRequest.connectionTimeout = self.configuration.defaultHttpConnectionTimeout;
                
                // and adding this to queue
                requestHolder = [[VDFPendingRequestHolder alloc] init];
                requestHolder.initialRequest = request;
                requestHolder.httpRequest = httpRequest;
                [requestHolder.waitingRequests addObject:request];
                
                [self.pendingRequests addObject:requestHolder];
            }
        }
    }
    
    if(requestHolder != nil) {
        // then we need to perform http action
        VDFLogD(@"Starting new http request.");
        [self startHttpRequest:requestHolder];
    }
    
    // if we readed response from cache so we invoking this after synchronization
    if(responseObject != nil) {
        VDFLogD(@"Invoking response delegate with response readed from cache.");
        [request onObjectResponse:responseObject withError:nil];
    }
}

- (void)clearRequestDelegate:(id<VDFUsersServiceDelegate>)requestDelegate {
    // find all requests with this response delegate object
    @synchronized(self.pendingRequests) {
        // clear all corresponding requests:
        for (VDFPendingRequestHolder *holder in self.pendingRequests) {
            for (id<VDFRequest> request in holder.waitingRequests) {
                [request clearDelegateIfEquals:requestDelegate];
            }
        }
    }
}

#pragma mark -
#pragma mark private methods implementation

- (void)retryRequest:(VDFPendingRequestHolder*)requestHolder {
    
    VDFLogD(@"Retrying request.");
    if(requestHolder.numberOfRetries > self.configuration.maxHttpRequestRetriesCount) {
        
        VDFLogD(@"We run out of the limit, so need to cancel request:\n%@", requestHolder.initialRequest);
        // we run out of the limit, so need to return an error and remove this request:
        [self stopRequest:requestHolder withDomainErrorCode:VDFErrorConnectionTimeout];
    }
    else {
        
        VDFLogD(@"Dispatching retry request (after %ui ms):\n%@", self.configuration.httpRequestRetryTimeSpan, requestHolder.initialRequest);
        // we still stay in the limit, so wait and make the request
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, self.configuration.httpRequestRetryTimeSpan * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            
            // check is ther still waiting delegates
            BOOL delegatesStillWaiting = NO;
            for (id<VDFRequest> waitingRequest in requestHolder.waitingRequests) {
                if([waitingRequest isDelegateAvailable]) {
                    delegatesStillWaiting = YES;
                    break;
                }
            }
            if(delegatesStillWaiting) {
                [self startHttpRequest:requestHolder];
            }
            else {
                VDFLogD(@"Nobody is waiting, removing request:%@", requestHolder.initialRequest);
                // if nobody is waiting, so we can remove this request:
                [self.pendingRequests removeObject:requestHolder];
            }
        });
    }
}

- (void)startHttpRequest:(VDFPendingRequestHolder*)requestHolder {
    
    VDFLogD(@"Starting http request:%@", requestHolder.initialRequest);
    VDFNetworkReachability *reachability = [VDFNetworkReachability reachabilityForInternetConnection];
    [reachability startNotifier];
    
    NetworkStatus status = [reachability currentReachabilityStatus];
    
    if(status == NotReachable) {
        VDFLogD(@"Internet is not avaialble.");
        [self stopRequest:requestHolder withDomainErrorCode:VDFErrorNoConnection];
    }
    else if (status != ReachableViaWWAN && [requestHolder.initialRequest isGSMConnectionRequired]) {
        VDFLogD(@"Request need 3G connection - there is not available any.");
        // not connected over 3G and request require 3G:
        [self stopRequest:requestHolder withDomainErrorCode:VDFErrorNoConnection];
    }
    else {
        
        // starting the request
        requestHolder.numberOfRetries++;
        NSString * requestUrl = [self.configuration.endpointBaseUrl stringByAppendingString:[requestHolder.initialRequest urlEndpointMethod]];
        if([requestHolder.initialRequest httpMethod] == HTTPMethodPOST) {
            [requestHolder.httpRequest post:requestUrl withBody:[requestHolder.initialRequest postBody]];
        }
        else {
            [requestHolder.httpRequest get:requestUrl];
        }
        VDFLogD(@"Request started.");
    }
}

- (void)stopRequest:(VDFPendingRequestHolder*)requestHolder withDomainErrorCode:(VDFErrorCode)errorCode {
    
    VDFLogD(@"Stopping request.");
    NSError *error = [[NSError alloc] initWithDomain:VodafoneErrorDomain code:errorCode userInfo:nil];
    for (id<VDFRequest> waitingRequest in requestHolder.waitingRequests) {
        [waitingRequest onObjectResponse:nil withError:error];
    }
    @synchronized(self.pendingRequests) {
        [self.pendingRequests removeObject:requestHolder];
    }
}

#pragma mark -
#pragma mark VDFHttpRequestDelegate implementation
- (void)httpRequest:(VDFHttpConnector*)request onResponse:(NSData*)data withError:(NSError *)error {
    
    VDFLogD(@"On http response");
    
    id<NSCoding> parsedObject = nil;
    VDFPendingRequestHolder *pendingRequestHolder = nil;
    
    @synchronized(self.pendingRequests) {
        
        // find proper request holder:
        for (VDFPendingRequestHolder *holder in self.pendingRequests) {
            if(holder.httpRequest == request) {
                pendingRequestHolder = holder;
                break;
            }
        }
        
        VDFLogD(@"For request: \n%@", pendingRequestHolder.initialRequest);
        VDFLogD(@"Http response code: \n%@", request.lastResponseCode);
        VDFLogD(@"Http response data: \n%@", data);
        
        if(pendingRequestHolder != nil && [pendingRequestHolder.initialRequest respondsToSelector:@selector(onHttpResponseCode:)]) {
            [pendingRequestHolder.initialRequest onHttpResponseCode:request.lastResponseCode];
        }
        
        // parse and cache retrieved data:
        if(error == nil && pendingRequestHolder != nil) {
            parsedObject = [pendingRequestHolder.initialRequest parseAndUpdateOnDataResponse:data];
            if([pendingRequestHolder.initialRequest isCachable]) {
                [[VDFSettings sharedCacheManager] cacheResponseObject:parsedObject forRequest:pendingRequestHolder.initialRequest];
            }
        }
    }
    
    if(pendingRequestHolder != nil) {
        // responding to all delegates:
        VDFLogD(@"Responding to request delegates started.");
        for (id<VDFRequest> waitingRequest in pendingRequestHolder.waitingRequests) {
            
            // send http response to all requests except the initial one:
            if(pendingRequestHolder.initialRequest != waitingRequest && [waitingRequest respondsToSelector:@selector(onHttpResponseCode:)]) {
                [pendingRequestHolder.initialRequest onHttpResponseCode:request.lastResponseCode];
            }
            
            [waitingRequest onObjectResponse:parsedObject withError:error];
        }
        VDFLogD(@"Responding to request delegates finished.");
        
        // is it finished ?
        if([pendingRequestHolder.initialRequest isSatisfied]) {
            VDFLogD(@"Request is finished, closing it.");
            // remove this request from queue
            [self.pendingRequests removeObject:pendingRequestHolder];
        }
        else {
            // if not retry with http pooling
            [self retryRequest:pendingRequestHolder];
        }
    }
}

@end
