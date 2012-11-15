//
//  MRAdHTMLRequest.m
//  talk-me
//
//  Created by Vadim Tsyganok on 11/12/12.
//  Copyright (c) 2012 talkme.im. All rights reserved.
//

#import "MRAdHTMLRequest.h"

@interface MRAdHTMLRequest(Private)<NSURLConnectionDelegate, UIWebViewDelegate>
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
    
    NSString* userAgent = [MRAdHTMLRequest defaultUserAgent];
    if (userAgent.length)
    {
        NSMutableURLRequest* r = [request mutableCopy];
        [r setValue:userAgent forHTTPHeaderField:@"User-Agent"];
        request = [r autorelease];
    }

    conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    data = [[NSMutableData alloc] init];
    
    return self;
}

- (id) init
{
        // just to test useragent we need this
    if (!(self = [super init])) return nil;
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

#define MAX_TIMEOUT_FOR_USER_AGENT 0.3
static NSString* _defaultUserAgent = nil;
+ (NSString*) defaultUserAgent
{
    static BOOL userAgentChecked = NO;
    
    if (userAgentChecked) return _defaultUserAgent;
    
    userAgentChecked = YES;
    
    UIWebView* w = [[UIWebView alloc] init];
    w.delegate = [[MRAdHTMLRequest alloc] init];
    [w loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.apple.com"]]];
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    while (_defaultUserAgent == nil) {
            // This executes another run loop.
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        if (CFAbsoluteTimeGetCurrent() > start + MAX_TIMEOUT_FOR_USER_AGENT)
        {
            [w stopLoading];
            break;
        }
    }

    [w release];
    
    return _defaultUserAgent;
}
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    BOOL wasNil = (_defaultUserAgent == nil);
	_defaultUserAgent = [[request valueForHTTPHeaderField:@"User-Agent"] copy];
    if (wasNil && _defaultUserAgent) {
        webView.delegate = nil;
        [self autorelease];
        [webView stopLoading];
    }
    
        // Return no, we don't care about executing an actual request.
	return NO;
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
