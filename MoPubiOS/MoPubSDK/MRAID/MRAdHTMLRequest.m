//
//  MRAdHTMLRequest.m
//  talk-me
//
//  Created by Vadim Tsyganok on 11/12/12.
//  Copyright (c) 2012 talkme.im. All rights reserved.
//

#import "MRAdHTMLRequest.h"

@interface MRAdHTMLRequest(Private)<NSURLConnectionDelegate>
@end

@implementation MRAdHTMLRequest
@synthesize originalRequest;
- (id) initWithRequest: (NSURLRequest*) request andDelegate: (NSObject<MRAdHTMLRequestDelegate>*) aDelegate
{
    if (!(self = [super init])) return nil;
        // Yes, we have to retain delegate for the duration of request
    delegate = [aDelegate retain];
        // Yes, we do have to reatain self for the duration of request do that to prevent crashes.
    [self retain];
    
    originalRequest = [request copy];

    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    data = [[NSMutableData alloc] init];
    
    return self;
}
- (void) dealloc
{
    [conn release];
    [delegate release];
    [originalRequest release];
    [data release];
    [super dealloc];
}

- (NSData*) data
{
    return data;
}
#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [data setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)aData
{
    [data appendData:aData];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [delegate htmlRequest:self didFailWithError:error];
        // We have to release what was retained.
    [delegate autorelease];
    delegate = nil;
    [self autorelease];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [delegate htmlRequest:self didCompleteWithData:data];
    
        // We have to release what was retained.
    [delegate autorelease];
    delegate = nil;
    [self autorelease];
}
@end
