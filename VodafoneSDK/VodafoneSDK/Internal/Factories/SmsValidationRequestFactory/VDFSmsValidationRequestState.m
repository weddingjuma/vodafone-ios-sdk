//
//  VDFSmsValidationRequestState.m
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 06/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFSmsValidationRequestState.h"
#import "VDFHttpConnectorResponse.h"
#import "VDFError.h"
#import "VDFRequestState.h"

@interface VDFSmsValidationRequestState ()
@property (nonatomic, strong) NSError *error;
@end

@implementation VDFSmsValidationRequestState

#pragma mark -
#pragma mark - VDFRequestState Impelemnetation

- (void)updateWithHttpResponse:(VDFHttpConnectorResponse*)response {
    if(response != nil && response.httpResponseCode != 200 && response.error == nil) {
        NSInteger errorCode = VDFErrorServerCommunication;
        if(response.httpResponseCode == 400) {
            errorCode = VDFErrorInvalidInput;
        }
        else if(response.httpResponseCode == 404) {
            errorCode = VDFErrorResolutionTimeout;
        }
        if(response.httpResponseCode == 403) {
            errorCode = VDFErrorOfResolution;
        }
        else if(response.httpResponseCode == 409) {
            errorCode = VDFErrorWrongSmsCode;
        }
        self.error = [[NSError alloc] initWithDomain:VodafoneErrorDomain code:errorCode userInfo:nil];
    }
}

- (NSError*)responseError {
    return self.error;
}

@end
