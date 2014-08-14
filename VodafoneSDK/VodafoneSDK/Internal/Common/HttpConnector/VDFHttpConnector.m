//
//  HttpRequest.m
//  HeApiIOsSdk
//
//  Created by Michał Szymańczyk on 08/07/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import "VDFHttpConnector.h"
#import "VDFError.h"
#import "VDFLogUtility.h"
#import "VDFNetworkReachability.h"

@interface VDFHttpConnector ()
@property (nonatomic, assign) id<VDFHttpConnectorDelegate> delegate;
@property (nonatomic, strong) NSMutableData *receivedData;

- (void)addHeadersToRequest:(NSMutableURLRequest*)request;

- (void)get:(NSString*)url;
- (void)post:(NSString*)url withBody:(NSData*)body;
@end

@implementation VDFHttpConnector

@synthesize lastResponseCode = _lastResponseCode;

- (instancetype)initWithDelegate:(id<VDFHttpConnectorDelegate>)delegate {
    self = [super init];
    if(self) {
        self.delegate = delegate;
        self.connectionTimeout = 60.0; // default if is not set from outside
        _lastResponseCode = 0;
    }
    return self;
}

- (NSInteger)startCommunication {
    
    VDFNetworkReachability *reachability = [VDFNetworkReachability reachabilityForInternetConnection];
    [reachability startNotifier];
    
    NetworkStatus status = [reachability currentReachabilityStatus];
    
    if(status == NotReachable) {
        VDFLogD(@"Internet is not avaialble.");
        return 1;
    }
    else if (status != ReachableViaWWAN && self.isGSMConnectionRequired) {
        VDFLogD(@"Request need 3G connection - there is not available any.");
        // not connected over 3G and request require 3G:
        return 2; // TODO need to make some error codes for this
    }
    else {
        
        // starting the request
        if(self.methodType == HTTPMethodPOST) {
            [self post:self.url withBody:self.postBody];
        }
        else {
            [self get:self.url];
        }
        VDFLogD(@"Request started.");
    }

    return 0;
}

#pragma mark -
#pragma mark Private implementation

- (void)addHeadersToRequest:(NSMutableURLRequest*)request {
    
    if(self.requestHeaders != nil) {
        for (NSString *headerKey in [self.requestHeaders allKeys]) {
            [request setValue:[self.requestHeaders valueForKey:headerKey] forHTTPHeaderField:headerKey];
        }
    }
    
}

- (void)get:(NSString*)url {
    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                     cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                 timeoutInterval:self.connectionTimeout];
    
    [self addHeadersToRequest:request];
    
    // sending request:
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    VDFLogD(@"GET %@", url);
    
    if(conn) {
        self.url = url;
        self.receivedData = [NSMutableData data];
    }
    else {
        NSError *error = [[NSError alloc] initWithDomain:VodafoneErrorDomain code:VDFErrorNoConnection userInfo:nil];
        [self.delegate httpRequest:self onResponse:nil withError:error];
    }
    
}

- (void)post:(NSString*)url withBody:(NSData*)body
{
    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:[NSURL URLWithString: url]
                            cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                        timeoutInterval:self.connectionTimeout];
    
    request.HTTPMethod = @"POST";
    
    //[request addValue:@"8bit" forHTTPHeaderField:@"Content-Transfer-Encoding"];
    [request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request addValue:[NSString stringWithFormat:@"%lu", (unsigned long)[body length]] forHTTPHeaderField:@"Content-Length"];
    
    [self addHeadersToRequest:request];
    
    [request setHTTPBody:body];
    
    VDFLogD(@"POST %@\n------\n%@\n------", url, [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
    
    // sending request:
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    if(conn) {
        self.url = url;
        self.receivedData = [NSMutableData data];
    }
    else {
        NSError *error = [[NSError alloc] initWithDomain:VodafoneErrorDomain code:VDFErrorNoConnection userInfo:nil];
        [self.delegate httpRequest:self onResponse:nil withError:error];
    }
}

#pragma mark -
#pragma mark NSURLConnectionDelegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        // accepting all ssl certificates
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge];
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    [self.receivedData setLength:0];
    _lastResponseCode = [(NSHTTPURLResponse*)response statusCode];
}

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data {
    [self.receivedData appendData:data];
}


- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
    NSError *errorInVDFDomain = [[NSError alloc] initWithDomain:VodafoneErrorDomain code:VDFErrorNoConnection userInfo:nil];
    [self.delegate httpRequest:self onResponse:nil withError:errorInVDFDomain];
}



- (void)connectionDidFinishLoading:(NSURLConnection*)connection {
    [self.delegate httpRequest:self onResponse:self.receivedData withError:nil];
}





@end
