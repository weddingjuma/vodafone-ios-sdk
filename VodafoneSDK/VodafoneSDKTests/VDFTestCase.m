//
//  VDFTestCase.m
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 28/10/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFTestCase.h"

extern void __gcov_flush();

@implementation VDFTestCase


- (void)tearDown
{
    __gcov_flush();
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


@end
