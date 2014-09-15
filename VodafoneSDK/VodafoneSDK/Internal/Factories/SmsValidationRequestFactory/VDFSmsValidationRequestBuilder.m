//
//  VDFSmsValidationRequestBuilder.m
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 06/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFSmsValidationRequestBuilder.h"
#import "VDFSmsValidationRequestFactory.h"
#import "VDFOAuthTokenRequestOptions.h"
#import "VDFOAuthTokenRequestBuilder.h"
#import "VDFBaseConfiguration.h"
#import "VDFError.h"
#import "VDFDIContainer.h"
#import "VDFConsts.h"

static NSString * const DESCRIPTION_FORMAT = @"VDFUserResolveRequestFactoryBuilder:\n\t urlEndpointMethod:%@ \n\t httpMethod:%@ \n\t applicationId:%@ \n\t sessionToke:%@ \n\t smsCode:%@ ";

@interface VDFSmsValidationRequestBuilder ()
@property (nonatomic, strong) VDFSmsValidationRequestFactory *internalFactory;
@end

@implementation VDFSmsValidationRequestBuilder

- (instancetype)initWithApplicationId:(NSString*)applicationId sessionToken:(NSString*)sessionToken smsCode:(NSString*)smsCode diContainer:(VDFDIContainer*)diContainer delegate:(id<VDFUsersServiceDelegate>)delegate {
    self = [super initWithApplicationId:applicationId diContainer:diContainer];
    if(self) {
        self.internalFactory = [[VDFSmsValidationRequestFactory alloc] initWithBuilder:self];
        
        _urlEndpointQuery = [NSString stringWithFormat:SERVICE_URL_SCHEME_VALIDATE_PIN, sessionToken, applicationId];
        _httpRequestMethodType = HTTPMethodPOST;
        self.sessionToken = sessionToken;
        self.smsCode = smsCode;
        self.oAuthToken = nil;
        
        if(delegate != nil) {
            [[self observersContainer] registerObserver:delegate];
        }
    }
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat: DESCRIPTION_FORMAT, [self urlEndpointQuery], ([self httpRequestMethodType] == HTTPMethodGET) ? @"GET":@"POST", self.applicationId, self.sessionToken, self.smsCode];
}

#pragma mark -
#pragma mark VDFRequestFactoryBuilder Implementation

- (id<VDFRequestFactory>)factory {
    return self.internalFactory;
}

- (BOOL)isEqualToFactoryBuilder:(id<VDFRequestBuilder>)builder {
    if(builder == nil || ![builder isKindOfClass:[VDFSmsValidationRequestBuilder class]]) {
        return NO;
    }
    
    VDFSmsValidationRequestBuilder * smsValidationBuilder = (VDFSmsValidationRequestBuilder*)builder;
    if(![self.applicationId isEqualToString:smsValidationBuilder.applicationId]) {
        return NO;
    }
    if(![self.sessionToken isEqualToString:smsValidationBuilder.sessionToken]) {
        return NO;
    }
    
    return [self.smsCode isEqualToString:smsValidationBuilder.smsCode];
}

#pragma mark -
#pragma mark VDFOAuthTokenRequestDelegate implementation

-(void)didReceivedOAuthToken:(VDFOAuthTokenResponse*)oAuthToken withError:(NSError*)error {
    if(oAuthToken != nil || error == nil) {
        // everything looks fine:
        self.oAuthToken = oAuthToken;
    }
    // error handling is done in decorator class so here we only expects to store valid token
}

@end
