//
//  MRAdView.m
//  MoPub
//
//  Created by Andrew He on 12/20/11.
//  Copyright (c) 2011 MoPub, Inc. All rights reserved.
//

#import "MRAdView.h"
#import "UIWebView+MPAdditions.h"
#import "MPGlobal.h"
#import "MPLogging.h"
#import "MRAdViewBrowsingController.h"
#import "MRAdViewDisplayController.h"
#import "MRCommand.h"
#import "MRProperty.h"
#import "MRAdHTMLRequest.h"

static NSString * const kExpandableCloseButtonImageName = @"MPCloseButtonX.png";
static NSString * const kMraidURLScheme = @"mraid";

@interface MRAdView ()<MRAdHTMLRequestDelegate>

//@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) MRAdViewBrowsingController *browsingController;
@property (nonatomic, retain) MRAdViewDisplayController *displayController;

- (void)loadRequest:(NSURLRequest *)request;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (NSMutableString *)HTMLWithJavaScriptBridge:(NSString *)HTML;
- (void)convertFragmentToFullPayload:(NSMutableString *)fragment;
- (NSString *)executeJavascript:(NSString *)javascript withVarArgs:(va_list)args;
- (void)layoutCloseButton;
- (void)fireChangeEventForProperty:(MRProperty *)property;
- (void)fireChangeEventsForProperties:(NSArray *)properties;
- (void)fireErrorEventForAction:(NSString *)action withMessage:(NSString *)message;
- (void)fireReadyEvent;
- (void)fireNativeCommandCompleteEvent:(NSString *)command;
- (void)initializeJavascriptState;
- (BOOL)tryProcessingURLStringAsCommand:(NSString *)urlString;
- (BOOL)tryProcessingCommand:(NSString *)command parameters:(NSDictionary *)parameters;

// Delegate callback methods wrapped with -respondsToSelector: checks.
- (void)adDidLoad;
- (void)adDidFailToLoad;
- (void)adWillClose;
- (void)adDidClose;
- (void)adDidRequestCustomCloseEnabled:(BOOL)enabled;
- (void)adWillExpandToFrame:(CGRect)frame;
- (void)adDidExpandToFrame:(CGRect)frame;
- (void)adWillPresentModalView;
- (void)adDidDismissModalView;
- (void)appShouldSuspend;
- (void)appShouldResume;
- (void)adViewableDidChange:(BOOL)viewable;

@end

@implementation MRAdView
@synthesize delegate = _delegate;
@synthesize usesCustomCloseButton = _usesCustomCloseButton;
@synthesize expanded = _expanded;
//@synthesize data = _data;
@synthesize browsingController = _browsingController;
@synthesize displayController = _displayController;
@synthesize forceExpandedOrientation = _forceExpandedOrientation;
@synthesize hideStatusBarWhenExpanded = _hideStatusBarWhenExpanded;
@synthesize overridenOverlayUrl = _overridenOverlayUrl;
@synthesize creativeLoader;

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame 
               allowsExpansion:YES 
              closeButtonStyle:MRAdViewCloseButtonStyleAdControlled 
                 placementType:MRAdViewPlacementTypeInline];
}

- (id)initWithFrame:(CGRect)frame allowsExpansion:(BOOL)expansion 
   closeButtonStyle:(MRAdViewCloseButtonStyle)style placementType:(MRAdViewPlacementType)type
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        CGSize s = frame.size;
        _webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, s.width, s.height)];
        _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | 
            UIViewAutoresizingFlexibleHeight;
        _webView.backgroundColor = [UIColor clearColor];
#ifdef DEBUG
        _webView.backgroundColor = [UIColor purpleColor];
#endif
        _webView.clipsToBounds = YES;
        _webView.delegate = self;
        _webView.opaque = NO;
        [_webView mp_setScrollable:NO];
        
        if ([_webView respondsToSelector:@selector(setAllowsInlineMediaPlayback:)]) {
            [_webView setAllowsInlineMediaPlayback:YES];
        }
        
        if ([_webView respondsToSelector:@selector(setMediaPlaybackRequiresUserAction:)]) {
            [_webView setMediaPlaybackRequiresUserAction:NO];
        }
        
        [self addSubview:_webView];
        
        _closeButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        _closeButton.frame = CGRectMake(0, 0, 50, 50);
        UIImage *image = [UIImage imageNamed:kExpandableCloseButtonImageName];
        [_closeButton setImage:image forState:UIControlStateNormal];
        
        _allowsExpansion = expansion;
        _closeButtonStyle = style;
        _placementType = type;
        
        _browsingController = [[MRAdViewBrowsingController alloc] initWithAdView:self];
        _displayController = [[MRAdViewDisplayController alloc] initWithAdView:self
                                                               allowsExpansion:expansion 
                                                              closeButtonStyle:style];
        
        [_closeButton addTarget:_displayController action:@selector(closeButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        _forceExpandedOrientation = UIDeviceOrientationUnknown;
    }
    return self;
}

- (void)dealloc {
    _webView.delegate = nil;
    [_webView release];
    [_closeButton release];
    [_overridenOverlayUrl release];
//    [_data release];
    [_browsingController release];
    [_displayController release];
    [super dealloc];
}

#pragma mark - Public

//- (void) setFrame:(CGRect)f
//{
//    [super setFrame:f];
//    CGSize s = f.size;
////    _webView.frame = CGRectMake(0, 0, s.width, s.height);
//    _webView.backgroundColor = [UIColor purpleColor];
//}

- (void)setDelegate:(id<MRAdViewDelegate>)delegate {
    [_closeButton removeTarget:delegate
                        action:NULL
              forControlEvents:UIControlEventTouchUpInside];
    
    _delegate = delegate;
    
    [_closeButton addTarget:_delegate 
                     action:@selector(closeButtonPressed)
           forControlEvents:UIControlEventTouchUpInside];
    
//    _browsingController.viewControllerForPresentingModalView =
//        [_delegate viewControllerForPresentingModalView];
}

- (void)setExpanded:(BOOL)expanded {
    _expanded = expanded;
    [self layoutCloseButton];
}

- (void)setUsesCustomCloseButton:(BOOL)shouldUseCustomCloseButton {
    _usesCustomCloseButton = shouldUseCustomCloseButton;
    [self layoutCloseButton];
}

- (NSString *)executeJavascript:(NSString *)javascript, ... {
    va_list args;
    va_start(args, javascript);
    NSString *result = [self executeJavascript:javascript withVarArgs:args];
    va_end(args);
    return result;
}

- (BOOL)isViewable {
    return MPViewIsVisible(self);
}

- (MRAdView*) expansionView
{
    MRAdView* v = _displayController.twoPartExpansionView;
    if (v) return v;
    return self;
}

- (void)loadCreativeFromURL:(NSURL *)url {
    [_displayController revertViewToDefaultState];
    _isLoading = YES;
    if (creativeLoader) {
        [creativeLoader loadCreativeAt:url for:self to:^void (NSURL* url1, NSString* html) {
            if (!_isLoading) return;
            if (html) [self loadHTMLString:html baseURL:url1];
            else [self adDidFailToLoad];
        }];
    }
    else
        [self loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)loadCreativeWithHTMLString:(NSString *)html baseURL:(NSURL *)url {
    [_displayController revertViewToDefaultState];
    _isLoading = YES;
    [self loadHTMLString:html baseURL:url];
}

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation {
    [_displayController rotateToOrientation:newOrientation];
}

- (NSString *)placementType {
    switch (_placementType) {
        case MRAdViewPlacementTypeInline: return @"inline";
        case MRAdViewPlacementTypeInterstitial: return @"interstitial";
        default: return @"unknown";
    }
}

#pragma mark - Javascript Communication API

- (void)fireChangeEventForProperty:(MRProperty *)property {
    NSString *JSON = [NSString stringWithFormat:@"{%@}", property];
    [self executeJavascript:@"window.mraidbridge.fireChangeEvent(%@);", JSON];
    MPLogDebug(@"JSON: %@", JSON);
}

- (void)fireChangeEventsForProperties:(NSArray *)properties {
    NSString *JSON = [NSString stringWithFormat:@"{%@}", 
                      [properties componentsJoinedByString:@", "]];
    [self executeJavascript:@"window.mraidbridge.fireChangeEvent(%@);", JSON];
    MPLogDebug(@"JSON: %@", JSON);
}

- (void)fireErrorEventForAction:(NSString *)action withMessage:(NSString *)message {
    [self executeJavascript:@"window.mraidbridge.fireErrorEvent('%@', '%@');", message, action];
}

- (void)fireReadyEvent {
    [self executeJavascript:@"window.mraidbridge.fireReadyEvent();"];
}

- (void)fireNativeCommandCompleteEvent:(NSString *)command {
    [self executeJavascript:@"window.mraidbridge.nativeCallComplete('%@');", command];
}

#pragma mark - Private

- (void)loadRequest:(NSURLRequest *)request {
    [[[MRAdHTMLRequest alloc]initWithRequest:request andDelegate:self] autorelease];
}

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    NSString *HTML = [self HTMLWithJavaScriptBridge:string];
    [_webView loadHTMLString:HTML baseURL:baseURL];
}

- (NSString*) mraidJsFragment
{
    static NSString* js = nil;
    if (js != nil) return js;
    
    NSString *mraidBundlePath = [[NSBundle mainBundle] pathForResource:@"MRAID" ofType:@"bundle"];
    NSBundle *mraidBundle = [NSBundle bundleWithPath:mraidBundlePath];
    NSString *mraidPath = [mraidBundle pathForResource:@"mraid" ofType:@"js"];
        //    NSURL *mraidUrl = [NSURL fileURLWithPath:mraidPath];
    
    NSString* str = [[NSString alloc] initWithContentsOfFile:mraidPath encoding:NSASCIIStringEncoding error:nil];
    js = [[NSString stringWithFormat:@"<head>\n<script>\n%@\n</script>\n", str] retain];
    [str release];
    return js;
}

- (NSMutableString *)HTMLWithJavaScriptBridge:(NSString *)HTML {
    NSRange htmlTagRange = [HTML rangeOfString:@"<html>"];
    NSRange headTagRange = [HTML rangeOfString:@"<head>"];
    BOOL isFragment = (htmlTagRange.location == NSNotFound || headTagRange.location == NSNotFound);
    
    NSMutableString *mutableHTML = [HTML mutableCopy];
    if (isFragment) [self convertFragmentToFullPayload:mutableHTML];

    
//    NSLog(@"mraid.js has %i characters", mraidJs.length);

    
    headTagRange = [mutableHTML rangeOfString:@"<head>"];
    [mutableHTML replaceCharactersInRange:headTagRange withString: self.mraidJsFragment];
    
//    [mutableHTML replaceCharactersInRange:headTagRange withString:
//     [NSString stringWithFormat:@"<head><script src='%@'></script>", [mraidUrl absoluteString]]];
//    NSLog(@"final HTML is:\n%@", mutableHTML);
    return [mutableHTML autorelease];
}

- (void)convertFragmentToFullPayload:(NSMutableString *)fragment {
    MPLogDebug(@"Fragment detected: converting to full payload.");
    NSString *prepend = @"<html><head>"
    @"<meta name='viewport' content='user-scalable=no; initial-scale=1.0; '/>"
    @"</head>"
    @"<body style='margin:0;padding:0;overflow:hidden;background:transparent;'>";
    [fragment insertString:prepend atIndex:0];
    [fragment appendString:@"</body></html>"];
}

- (NSString *)executeJavascript:(NSString *)javascript withVarArgs:(va_list)args {
    NSString *js = [[[NSString alloc] initWithFormat:javascript arguments:args] autorelease];
        //NSLog(@"Java script to execute:\n%@", js);
    return [_webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)layoutCloseButton {
    if (!_usesCustomCloseButton && _expanded) {
        CGRect frame = _closeButton.frame;
        frame.origin.x = CGRectGetWidth(CGRectApplyAffineTransform(self.frame, self.transform)) - 
        _closeButton.frame.size.width;
        _closeButton.frame = frame;
        _closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        if (_closeButton.superview != self) [self addSubview:_closeButton];
        [self bringSubviewToFront:_closeButton];
    } else {
        [_closeButton removeFromSuperview];
    }
}

- (void)initializeJavascriptState {
    MPLogDebug(@"Injecting initial JavaScript state.");
    [self fireChangeEventForProperty:[MRPlacementTypeProperty propertyWithType:_placementType]];
    [_displayController initializeJavascriptState];
    [self fireReadyEvent];
    
//    NSString* mraid = [self executeJavascript:@"window.mraidbridge"];
//    NSLog(@"mraid is %@", mraid);
}

- (BOOL)tryProcessingURLStringAsCommand:(NSString *)urlString {
    NSString *scheme = [NSString stringWithFormat:@"%@://", kMraidURLScheme];
    NSString *schemelessUrlString = [urlString substringFromIndex:scheme.length];
    
    NSRange r = [schemelessUrlString rangeOfString:@"?"];
    
    if (r.location == NSNotFound) {
        return [self tryProcessingCommand:schemelessUrlString parameters:nil];
    }
    
    NSString *commandType = [[schemelessUrlString substringToIndex:r.location] lowercaseString];
    NSString *parameterString = [schemelessUrlString substringFromIndex:(r.location + 1)];
    NSDictionary *parameters = MPDictionaryFromQueryString(parameterString);
    
    return [self tryProcessingCommand:commandType parameters:parameters];
}

- (BOOL)tryProcessingCommand:(NSString *)command parameters:(NSDictionary *)parameters {
    MRCommand *cmd = [MRCommand commandForString:command];
    cmd.parameters = parameters;
    cmd.view = self;
    
    BOOL processed = [cmd execute];
    if (!processed) MPLogDebug(@"Unknown command: %@", command);
    
    [self fireNativeCommandCompleteEvent:command];
    
    return processed;
}

#pragma mark - MRAdHTMLRequestDelegate
- (void) htmlRequest:(MRAdHTMLRequest *)request didCompleteWithData:(NSData *)data
{
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self loadHTMLString:str baseURL:request.originalRequest.URL];
    [str release];
}
- (void) htmlRequest:(MRAdHTMLRequest *)request didFailWithError:(NSError *)error
{
    [self adDidFailToLoad];
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request 
 navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    NSMutableString *urlString = [NSMutableString stringWithString:[url absoluteString]];
    NSString *scheme = url.scheme;
    
    if ([scheme isEqualToString:kMraidURLScheme]) {
        MPLogDebug(@"Trying to process command: %@", urlString);
        BOOL success = [self tryProcessingURLStringAsCommand:urlString];
        if (success) return NO;
    }
    
    if ([scheme isEqualToString:@"tel"] || [scheme isEqualToString:@"telto"] || [scheme isEqualToString:@"mailto"] ||[scheme isEqualToString:@"sms"] || [scheme isEqualToString:@"smsto"]) {
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
            return NO;
        }
        return YES;
    } else if ([scheme isEqualToString:@"mopub"]) {
        return NO;
    } else if ([scheme isEqualToString:@"ios-log"]) {
        [urlString replaceOccurrencesOfString:@"%20" 
                                   withString:@" " 
                                      options:NSLiteralSearch 
                                        range:NSMakeRange(0, [urlString length])];
        MPLogDebug(@"Web console: %@", urlString);
        return NO;
    }
    
    if (!_isLoading && navigationType == UIWebViewNavigationTypeOther) {
        BOOL iframe = ![request.URL isEqual:request.mainDocumentURL];
        if (iframe) return YES;
        
        [_browsingController openBrowserWithUrlString:urlString 
                                           enableBack:YES 
                                        enableForward:YES 
                                        enableRefresh:YES];
        return NO;
    }
    
    if (!_isLoading && navigationType == UIWebViewNavigationTypeLinkClicked) {
        [[UIApplication sharedApplication] openURL:url];
        return NO;
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (_isLoading) {
        _isLoading = NO;
        [self adDidLoad];
        [self initializeJavascriptState];
        [self layoutCloseButton];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    _isLoading = NO;
    [self adDidFailToLoad];
}

#pragma mark - Delegation Wrappers

- (void)adDidLoad {
    if ([self.delegate respondsToSelector:@selector(adDidLoad:)]) {
        [self.delegate adDidLoad:self];
    }
}

- (void)adDidFailToLoad {
    if ([self.delegate respondsToSelector:@selector(adDidFailToLoad:)]) {
        [self.delegate adDidFailToLoad:self];
    }
}

- (void)adWillClose {
    if ([self.delegate respondsToSelector:@selector(adWillClose:)]) {
        [self.delegate adWillClose:self];
    }
}

- (void)adDidClose {
    if ([self.delegate respondsToSelector:@selector(adDidClose:)]) {
        [self.delegate adDidClose:self];
    }
}

- (void)adWillExpandToFrame:(CGRect)frame {
    if ([self.delegate respondsToSelector:@selector(willExpandAd:toFrame:)]) {
        [self.delegate willExpandAd:self toFrame:frame];
    }
}

- (void)adDidExpandToFrame:(CGRect)frame {
    if ([self.delegate respondsToSelector:@selector(didExpandAd:toFrame:)]) {
        [self.delegate didExpandAd:self toFrame:frame];
    }
}

- (void)adDidRequestCustomCloseEnabled:(BOOL)enabled {
    if ([self.delegate respondsToSelector:@selector(ad:didRequestCustomCloseEnabled:)]) {
        [self.delegate ad:self didRequestCustomCloseEnabled:enabled];
    }
}

- (void)adWillPresentModalView {
    [_displayController additionalModalViewWillPresent];
    
    _modalViewCount++;
    if (_modalViewCount == 1) [self appShouldSuspend];
}

- (void)adDidDismissModalView {
    [_displayController additionalModalViewDidDismiss];
    
    _modalViewCount--;
    NSAssert((_modalViewCount >= 0), @"Modal view count cannot be negative.");
    if (_modalViewCount == 0) [self appShouldResume];
}

- (void)appShouldSuspend {
    if ([self.delegate respondsToSelector:@selector(appShouldSuspendForAd:)]) {
        [self.delegate appShouldSuspendForAd:self];
    }
}

- (void)appShouldResume {
    if ([self.delegate respondsToSelector:@selector(appShouldResumeFromAd:)]) {
        [self.delegate appShouldResumeFromAd:self];
    }
}

- (void)adViewableDidChange:(BOOL)viewable {
    [self fireChangeEventForProperty:[MRViewableProperty propertyWithViewable:viewable]];
}

@end
