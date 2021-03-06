//
//  VDFError.h
//  HeApiIOsSdk
//
//  Created by Michał Szymańczyk on 08/07/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import <Foundation/Foundation.h>


static NSString * const VodafoneErrorDomain = @"com.vodafone.seamlessIdSdk.ErrorDomain";

/*!
 @typedef NS_ENUM (NSUInteger, VDFErrorCode)
 @abstract Error codes returned by the Vodafone SDK in NSError.
 
 @discussion
 These are valid only in the scope of VodafoneSDKDomain.
 */
typedef NS_ENUM(NSInteger, VDFErrorCode) {
    /*!
     There is no available connection to the internet
     */
    VDFErrorNoConnection = 0,
    /*!
     Connection to the endpoint has timeouted
     */
    VDFErrorConnectionTimeout,
    /*!
     Problems in communication with server.
     */
    VDFErrorServerCommunication,
    /*!
     To many calls in last time period.
     */
    VDFErrorThrottlingLimitExceeded,
    /*!
     The request has not passed the input validation.
     */
    VDFErrorInvalidInput,
    /*!
     Session token used in the process has expired or was wrong.
     */
    VDFErrorResolutionTimeout,
    /*!
     Wrong sms code provided for Validate PIN.
     */
    VDFErrorWrongSmsCode,
    /*!
     *  Error in authorization over APIX.
     */
    VDFErrorAuthorizationFailed,
    /**
     *  Mobile country code included in msisdn is not supported by user resolve or user resolve cannot be continued because device is in another cellurar network than Vodafone.
     */
    VDFErrorOperatorNotSupported,
    /**
     *  Any other error scenario
     */
    VDFErrorOfResolution,
};


