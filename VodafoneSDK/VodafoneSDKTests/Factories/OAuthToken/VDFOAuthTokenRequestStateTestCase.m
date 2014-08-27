//
//  VDFOAuthTokenRequestStateTestCase.m
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 26/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "VDFOAuthTokenRequestState.h"
#import "VDFHttpConnectorResponse.h"
#import "VDFOAuthTokenResponse.h"

extern void __gcov_flush();

@interface VDFOAuthTokenRequestStateTestCase : XCTestCase
@property VDFOAuthTokenRequestState *requestStateToTest;

- (void)assertForInitialState;
@end

@implementation VDFOAuthTokenRequestStateTestCase

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.requestStateToTest = [[VDFOAuthTokenRequestState alloc] init];
}

- (void)tearDown
{
    __gcov_flush();
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitialState {
    [self assertForInitialState];
}

- (void)testUpdateWithHttpResponse {
    // run & assert
    [self.requestStateToTest updateWithHttpResponse:nil];
    [self assertForInitialState];
    
    // run & assert
    [self.requestStateToTest updateWithHttpResponse:(VDFHttpConnectorResponse*)@"fakeMock"];
    [self assertForInitialState];
}

- (void)testUpdateWithInvalidResponse {
    
    // run & assert
    [self.requestStateToTest updateWithParsedResponse:nil];
    [self assertForInitialState];
    
    // run & assert
    [self.requestStateToTest updateWithParsedResponse:@"fakeMock"];
    [self assertForInitialState];
}

- (void)testUpdateWithValidResponse {
    
    // mock
    NSDate *expirationDate = [NSDate date];
    id response = OCMClassMock([VDFOAuthTokenResponse class]);
    
    // stub
    [[[response stub] andReturn:expirationDate] expiresIn];
    
    // run
    [self.requestStateToTest updateWithParsedResponse:response];
    
    // assert
    XCTAssertFalse([self.requestStateToTest isRetryNeeded], @"OAuthToken request will never retry.");
    XCTAssertEqualObjects([self.requestStateToTest lastResponseExpirationDate], expirationDate, @"Expiration date should be readed from valid response object.");
}

#pragma mark - private methods
- (void)assertForInitialState {
    XCTAssertFalse([self.requestStateToTest isRetryNeeded], @"OAuthToken request will never retry.");
    XCTAssertTrue([[self.requestStateToTest lastResponseExpirationDate] compare:[NSDate date]] == NSOrderedAscending, @"OAuthToken request should have date previus than current because is expired as default.");
}

@end