//
//  VDFSettingsTestCase.m
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 25/07/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import <XCTest/XCTest.h>

extern void __gcov_flush();

@interface VDFSettingsTestCase : XCTestCase

@end

@implementation VDFSettingsTestCase

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    __gcov_flush();
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    // TODO
//    XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
}

@end
