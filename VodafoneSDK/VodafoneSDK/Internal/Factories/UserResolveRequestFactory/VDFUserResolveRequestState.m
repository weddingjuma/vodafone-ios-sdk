//
//  VDFUserResolveRequestState.m
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 04/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFUserResolveRequestState.h"
#import "VDFLogUtility.h"
#import "VDFUserTokenDetails.h"
#import "VDFUserResolveRequestBuilder.h"
#import "VDFHttpConnectorResponse.h"
#import "VDFError.h"
#import "VDFDIContainer.h"
#import "VDFBaseConfiguration.h"
#import "VDFConsts.h"
#import "VDFRequestState.h"
#import "VDFSmsValidationRequestBuilder.h"
#import "VDFRequestBuilderWithOAuth.h"
#import "VDFSmsSendPinRequestBuilder.h"
#import "VDFUserTokenDetails+Internal.h"
#import "VDFRequestStateWithOAuth.h"

@interface VDFUserResolveRequestState ()
@property BOOL needRetry;
@property NSTimeInterval retryAfterMiliseconds;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) VDFUserResolveRequestBuilder *builder;
@property (nonatomic, assign) VDFResolutionStatus currentResolutionStatus;

- (void)readEtagFromResponse:(VDFHttpConnectorResponse*)response;
- (void)readErrorFromResponse:(VDFHttpConnectorResponse*)response;
@end

@implementation VDFUserResolveRequestState

- (instancetype)initWithBuilder:(VDFUserResolveRequestBuilder*)builder {
    self = [super init];
    if(self) {
        self.needRetry = YES; // as default this request is waiting on server changes
        self.builder = builder;
        self.retryAfterMiliseconds = -1;
        self.currentResolutionStatus = VDFResolutionStatusUnableToResolve;
    }
    return self;
}

- (void)readEtagFromResponse:(VDFHttpConnectorResponse*)response {
    if(response.responseHeaders != nil && [[response.responseHeaders allKeys] containsObject:HTTP_HEADER_ETAG]) {
        NSString *etag = [response.responseHeaders objectForKey:HTTP_HEADER_ETAG];
        self.builder.eTag = etag;
    }
    
    if(self.builder.eTag == nil && self.needRetry) {
        self.builder.eTag = CHECK_STATUS_ETAG_INITIAL_VALUE; // in that case we need to set any to inform builder that we need to make first retry request
    }
}

- (void)readErrorFromResponse:(VDFHttpConnectorResponse*)response {
    if(response.httpResponseCode != 201 && response.httpResponseCode != 200 && response.httpResponseCode != 302
       && response.httpResponseCode != 404 && response.httpResponseCode != 304 && response.error == nil) {
        NSInteger errorCode = VDFErrorServerCommunication;
        if(response.httpResponseCode == 400) {
            errorCode = VDFErrorInvalidInput;
        }
        if(response.httpResponseCode == 403) {
            errorCode = VDFErrorOfResolution;
        }
        self.error = [[NSError alloc] initWithDomain:VodafoneErrorDomain code:errorCode userInfo:nil];
    }
}

- (void)readSessionTokenFromResponse:(VDFHttpConnectorResponse*)response {
    
    if(response.httpResponseCode == 302) {
        
        NSString *locationHeader = [response.responseHeaders objectForKey:HTTP_HEADER_LOCATION];
        
        // try to parse the location header
        if(locationHeader != nil) {
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"/users/tokens/([^?/]+)[?/]" options:NSRegularExpressionCaseInsensitive error:nil];
            NSArray *matches = [regex matchesInString:locationHeader options:0 range:NSMakeRange(0, [locationHeader length])];
            NSTextCheckingResult *match = [matches objectAtIndex:0];
            if(match != nil) {
                self.builder.sessionToken = [locationHeader substringWithRange:NSMakeRange(match.range.location+14, match.range.length-15)];
            }
        }
    }
}

#pragma mark -
#pragma mark - VDFRequestState Impelemnetation

- (void)updateWithHttpResponse:(VDFHttpConnectorResponse*)response {
    // check for etag
    // if exists update it in builder
    if(response != nil) {
        
        self.needRetry = response.httpResponseCode == 302 || response.httpResponseCode == 304;
        
        [self readEtagFromResponse:response];
        
        [self readSessionTokenFromResponse:response];
        
        if(response.responseHeaders != nil && [[response.responseHeaders allKeys] containsObject:HTTP_HEADER_RETRY_AFTER]) {
            self.retryAfterMiliseconds = [[response.responseHeaders objectForKey:HTTP_HEADER_RETRY_AFTER] doubleValue];
        }
        
        [self readErrorFromResponse:response];
    }
}

- (void)updateWithParsedResponse:(id)parsedResponse {
    
    if(parsedResponse != nil && [parsedResponse isKindOfClass:[VDFUserTokenDetails class]]) {
        
        VDFUserTokenDetails *userTokenDetails = (VDFUserTokenDetails*)parsedResponse;
        NSString *sessionToken = userTokenDetails.token ?: userTokenDetails.tokenOfPendingResolution;
        if(sessionToken != nil) {
            self.builder.sessionToken = sessionToken;
        }
        
        self.currentResolutionStatus = userTokenDetails.resolutionStatus;
    }
}

- (BOOL)isRetryNeeded {
    return self.needRetry;
}

- (NSTimeInterval)retryAfter {
    if(self.retryAfterMiliseconds > 0) {
        return self.retryAfterMiliseconds;
    }
    return 0;
}

- (BOOL)isConnectedRequestResponseNeeded {
    if(self.currentResolutionStatus == VDFResolutionStatusValidationRequired) {
        return YES; // when sms validation is needed then we waiting for aproporiate response
    }
    return NO;
}

- (BOOL)canHandleResponse:(VDFHttpConnectorResponse*)response ofConnectedBuilder:(id<VDFRequestBuilder>)builder {
    
    // this response can be handled if it is response of smsValidation and it is success
    // or in any other cases when sessionToken expire
    
    BOOL isExpectedResponse = NO;
    if([self isConnectedRequestResponseNeeded] && [builder isKindOfClass:[VDFRequestBuilderWithOAuth class]] && response != nil) {
        VDFRequestBuilderWithOAuth *builderWithOAuth = (VDFRequestBuilderWithOAuth*)builder;
        NSError *errorInResponse = [[builder requestState] responseError];
        
        // read session token of buulder from parameter:
        NSString *responseSessionToken = nil;
        if([builderWithOAuth.currentlyDecoratedBuilder isKindOfClass:[VDFSmsValidationRequestBuilder class]]) {
            responseSessionToken = ((VDFSmsValidationRequestBuilder*)builderWithOAuth.currentlyDecoratedBuilder).sessionToken;
            
            // check of successful validation of sms token
            isExpectedResponse = errorInResponse == nil && response.httpResponseCode == 200;
            
            // check for session token expiration
            isExpectedResponse = isExpectedResponse || (errorInResponse != nil && [errorInResponse code] == VDFErrorResolutionTimeout);
            
        } else if([builderWithOAuth.currentlyDecoratedBuilder isKindOfClass:[VDFSmsSendPinRequestBuilder class]]) {
            responseSessionToken = ((VDFSmsSendPinRequestBuilder*)builderWithOAuth.currentlyDecoratedBuilder).sessionToken;
            
            // check for session token expiration
            isExpectedResponse = isExpectedResponse || (errorInResponse != nil && [errorInResponse code] == VDFErrorResolutionTimeout);
        }
        
        // be sure is this part of the same resolution process:
        isExpectedResponse = isExpectedResponse && responseSessionToken != nil && self.builder.sessionToken != nil
                            && [responseSessionToken isEqualToString:self.builder.sessionToken];
        
        
        // check is this oAuth token response, if it is from oAuth then we cannot handle this:
        id requestState = [builderWithOAuth requestState];
        if([requestState isKindOfClass:[VDFRequestStateWithOAuth class]]) {
            VDFRequestStateWithOAuth *requestStateOAuth = (VDFRequestStateWithOAuth*)requestState;
            isExpectedResponse = isExpectedResponse && !requestStateOAuth.needRetryForOAuth;
        }
    }
    
    if(isExpectedResponse) {
        // we need to retry request imidettly:
        self.retryAfterMiliseconds = 0;
        self.currentResolutionStatus = VDFResolutionStatusUnableToResolve;
    }
    
    return isExpectedResponse;
}

- (NSError*)responseError {
    return self.error;
}

@end
