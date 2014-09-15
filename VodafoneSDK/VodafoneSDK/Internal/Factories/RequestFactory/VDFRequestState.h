//
//  VDFRequestState.h
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 04/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VDFHttpConnectorResponse;

/**
 *  Protocol for storing state of SDK request.
 */
@protocol VDFRequestState <NSObject>

/**
 *  Updates request state when http response code changes.
 *
 *  @param response Current repsonse object of http connection.
 */
- (void)updateWithHttpResponse:(VDFHttpConnectorResponse*)response;

/**
 *  Updates request state when response is received and parsed.
 *
 *  @param parsedResponse Response object returned from parser.
 */
- (void)updateWithParsedResponse:(id)parsedResponse;

/**
 *  Indicates is this request has finished or need to retry the http request.
 *
 *  @return YES - when need to retry, NO - when not need to retry the http request.
 */
- (BOOL)isRetryNeeded;

- (NSTimeInterval)retryAfter;

/**
 *  Indicates date when last response has to be expired.
 *
 *  @return Date object
 */
- (NSDate*)lastResponseExpirationDate;

- (NSError*)responseError;

@end
