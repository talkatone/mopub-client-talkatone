//
//  MRAdViewDisplayController.m
//  MoPub
//
//  Created by Andrew He on 12/22/11.
//  Copyright (c) 2011 MoPub, Inc. All rights reserved.
//

#import "MRAdViewDisplayController.h"
#import "MRAdView+Controllers.h"
#import "MRDimmingView.h"
#import "MRProperty.h"
#import "MPGlobal.h"
#import "MPLogging.h"
#import "MPTimer.h"

static NSString * const kAnimationKeyExpand = @"expand";
static NSString * const kAnimationKeyCloseExpanded = @"closeExpanded";
static NSString * const kAnimationKeyRotateExpanded = @"rotateExpanded";
static NSString * const kViewabilityTimerNotificationName = @"Viewability";
static const NSTimeInterval kViewabilityTimerInterval = 1.0;

static NSString *const kMovieDidEnterNotification43 = 
    @"UIMoviePlayerControllerDidEnterFullscreenNotification";
static NSString *const kMovieWillExitNotification43 = 
    @"UIMoviePlayerControllerWillExitFullscreenNotification";
static NSString *const kMovieDidEnterNotification42 = 
    @"UIMoviePlayerControllerDidEnterFullcreenNotification";
static NSString *const kMovieWillExitNotification42 = 
    @"UIMoviePlayerControllerWillExitFullcreenNotification";

@interface MRAdViewDisplayController ()

@property (nonatomic, retain, readwrite) MRAdView *twoPartExpansionView;

- (CGRect)defaultPosition;
- (void)checkViewability;

// Helpers for close() API.
- (void)closeFromExpandedState;
- (void)animateFromExpandedStateToDefaultState;
- (void)closeExpandAnimationDidStop;

// Helpers for expand() API.
- (void)rotateExpandedWindowsToCurrentOrientation;
- (void)saveCurrentViewTransform;
- (void)applyRotationTransformForCurrentOrientationOnView:(UIView *)view;
- (void)assignRandomTagToDefaultSuperview;
- (void)moveViewFromDefaultSuperviewToWindow;
- (void)moveViewFromWindowToDefaultSuperview;
- (void)animateViewFromDefaultStateToExpandedState:(UIView *)view;
- (void)constrainViewBoundsToApplicationFrame;
- (void)hideExpandedElementsIfNeeded;
- (void)unhideExpandedElementsIfNeeded;
- (CGRect)orientationAdjustedRect:(CGRect)rect;
- (CGRect)convertRectToWindowForCurrentOrientation:(CGRect)rect;
- (void)expandAnimationDidStop;

- (void)moviePlayerWillEnterFullscreen:(NSNotification *)notification;
- (void)moviePlayerDidExitFullscreen:(NSNotification *)notification;
- (UIInterfaceOrientation) orientationForExpandedView;
- (CGRect) applicationFrameForExpansionView;
@end

@implementation MRAdViewDisplayController
@synthesize view = _view;
@synthesize currentState = _currentState;
@synthesize twoPartExpansionView = _twoPartExpansionView;

- (id)initWithAdView:(MRAdView *)adView allowsExpansion:(BOOL)allowsExpansion 
    closeButtonStyle:(MRAdViewCloseButtonStyle)closeButtonStyle
{
    self = [super init];
    if (self) {
        _view = adView;
        _allowsExpansion = allowsExpansion;
        _closeButtonStyle = closeButtonStyle;
        
        _currentState = MRAdViewStateDefault;
        _defaultFrame = _view.frame;
        _maxSize = _view.frame.size;
        
        _viewabilityTimerTarget = [[MPTimerTarget alloc] 
                                   initWithNotificationName:kViewabilityTimerNotificationName];
        _viewabilityTimer = [[MPTimer scheduledTimerWithTimeInterval:kViewabilityTimerInterval
                                                              target:_viewabilityTimerTarget
                                                            selector:@selector(postNotification)
                                                            userInfo:nil
                                                             repeats:YES] retain];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(checkViewability)
                                                     name:kViewabilityTimerNotificationName 
                                                   object:_viewabilityTimerTarget];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(moviePlayerWillEnterFullscreen:)
                                                     name:kMovieDidEnterNotification43
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(moviePlayerWillEnterFullscreen:)
                                                     name:kMovieDidEnterNotification42
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(moviePlayerDidExitFullscreen:)
                                                     name:kMovieWillExitNotification43
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(moviePlayerDidExitFullscreen:)
                                                     name:kMovieWillExitNotification42
                                                   object:nil];
        
        _dimmingView = [[MRDimmingView alloc] initWithFrame:MPKeyWindow().frame];
        _dimmingView.backgroundColor = [UIColor darkGrayColor];
        _dimmingView.dimmingOpacity = 0.5;
    }
    return self;
}

- (void)dealloc {
    [_twoPartExpansionView release];
    [_viewabilityTimer invalidate];
    [_viewabilityTimer release];
    [_viewabilityTimerTarget release];
    [_dimmingView release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

#pragma mark - Public

- (void)initializeJavascriptState {
    NSArray *properties = [NSArray arrayWithObjects:
                           [MRScreenSizeProperty propertyWithSize:MPApplicationFrame().size],
                           [MROrientationProperty propertyWithOrientation:MPInterfaceOrientation()],
                           [MRStateProperty propertyWithState:_currentState],
                           nil];
    
    [_view fireChangeEventsForProperties:properties];
}

- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation {
    NSArray* properties = [NSArray arrayWithObjects:
                           [MRScreenSizeProperty propertyWithSize:MPApplicationFrame().size],
                           [MROrientationProperty propertyWithOrientation:newOrientation],
                           nil];
    [_view fireChangeEventsForProperties:properties];
    [self rotateExpandedWindowsToCurrentOrientation];
}

#pragma mark - Internal

- (CGRect)defaultPosition {
    UIWindow *keyWindow = MPKeyWindow();
    UIView *defaultSuperview = (_currentState == MRAdViewStateExpanded) ? 
        [keyWindow viewWithTag:_parentTag] : self.view.superview;   
    CGRect defaultPosition = [defaultSuperview convertRect:_defaultFrame toView:keyWindow];
    defaultPosition = [self orientationAdjustedRect:defaultPosition];
    return defaultPosition;
}

#pragma mark - Close API

- (void)close {
    [[UIApplication sharedApplication] setStatusBarHidden:_originalStatusBarVisibility withAnimation:UIStatusBarAnimationNone];
    [_view adWillClose];
    
    switch (_currentState) {
        case MRAdViewStateDefault: 
            _currentState = MRAdViewStateHidden; 
            [_view fireChangeEventForProperty:
             [MRStateProperty propertyWithState:_currentState]];
            break;
        case MRAdViewStateExpanded: 
            [self closeFromExpandedState];
            break;
    }
             
    [_view adDidClose];
}

#pragma mark - Close Helpers

- (void)closeFromExpandedState {
    _expansionContentView.usesCustomCloseButton = YES;
    
    // Calculate the frame of our original parent view in the window coordinate space.
    UIWindow *keyWindow = MPKeyWindow();
    UIView *parentView = [keyWindow viewWithTag:_parentTag];
    _defaultFrameInKeyWindow = [parentView convertRect:_defaultFrame toView:keyWindow];
    
    [self animateFromExpandedStateToDefaultState];
}

- (void)animateFromExpandedStateToDefaultState {
    // Transition the current expanded frame to the window-translated frame.
    [UIView beginAnimations:kAnimationKeyCloseExpanded context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    
    // Fade out the blocking view.
    _dimmingView.dimmed = NO;
    
    _expansionContentView.frame = _defaultFrameInKeyWindow;
    
    [UIView commitAnimations];
    
    // After the transition animation is complete, animationDidStop:finished:context: will be 
    // called, at which point our view will be removed from the key window and placed back within
    // its original parent.
}

#pragma mark - Expand API

- (void)expandToFrame:(CGRect)frame withURL:(NSURL *)url 
       useCustomClose:(BOOL)shouldUseCustomClose isModal:(BOOL)isModal 
shouldLockOrientation:(BOOL)shouldLockOrientation {
    if (!_allowsExpansion) return;
    [self useCustomClose:shouldUseCustomClose];
    [self expandToFrame:frame withURL:url blockingColor:[UIColor blackColor] 
        blockingOpacity:0.5 shouldLockOrientation:shouldLockOrientation];
}

- (void)expandToFrame:(CGRect)frame withURL:(NSURL *)url blockingColor:(UIColor *)blockingColor
      blockingOpacity:(CGFloat)blockingOpacity shouldLockOrientation:(BOOL)shouldLockOrientation {
    
    if (_view.overridenOverlayUrl) url = _view.overridenOverlayUrl;
    
    BOOL forcedOrientation = _view.forceExpandedOrientation != UIDeviceOrientationUnknown;
    if (forcedOrientation) {
        frame = self.applicationFrameForExpansionView;
    }
    _originalStatusBarVisibility = [UIApplication sharedApplication].statusBarHidden;
    if (_view.hideStatusBarWhenExpanded)
        [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    
    // Save our current frame as the default frame.
    _defaultFrame = self.view.frame;
    _expandedFrame = frame;
    
    [_view adWillExpandToFrame:_expandedFrame];
    [_view adWillPresentModalView];
    
    _dimmingView.backgroundColor = blockingColor;
    _dimmingView.dimmingOpacity = blockingOpacity;
    [MPKeyWindow() addSubview:_dimmingView];
    

    
    if (url) {
        self.twoPartExpansionView = [[[MRAdView alloc] initWithFrame:self.view.frame 
                                                     allowsExpansion:NO
                                                    closeButtonStyle:_closeButtonStyle
                                                       placementType:MRAdViewPlacementTypeInline] autorelease];
        if (_closeButtonStyle == MRAdViewCloseButtonStyleAlwaysVisible)
            self.twoPartExpansionView.usesCustomCloseButton = NO;
        
        self.twoPartExpansionView.delegate = self;
        self.twoPartExpansionView.creativeLoader = _view.creativeLoader;
        self.twoPartExpansionView.forceExpandedOrientation = _view.forceExpandedOrientation;
        self.twoPartExpansionView.hideStatusBarWhenExpanded = _view.hideStatusBarWhenExpanded;
        MRAdViewDisplayController* other = [self.twoPartExpansionView displayController];
        other->_originalStatusBarVisibility = _originalStatusBarVisibility;
        self.twoPartExpansionView.expanded = YES;
        [self.twoPartExpansionView loadCreativeFromURL:url];
        
        _expansionContentView = self.twoPartExpansionView;
        
        [self saveCurrentViewTransform];
        [self applyRotationTransformForCurrentOrientationOnView:_expansionContentView];
        [self assignRandomTagToDefaultSuperview];
        
        UIWindow *keyWindow = MPKeyWindow();
        
        _defaultFrameInKeyWindow = [self.view.superview convertRect:_defaultFrame toView:keyWindow];
        _expansionContentView.frame = _defaultFrameInKeyWindow;
        [keyWindow addSubview:_expansionContentView];
        [self.view removeFromSuperview];
    } else {
        _expansionContentView = self.view;
        [self moveViewFromDefaultSuperviewToWindow];
    }
    
    [self animateViewFromDefaultStateToExpandedState:_expansionContentView];
}

- (UIInterfaceOrientation) orientationForExpandedView
{
    UIDeviceOrientation o = _view.forceExpandedOrientation;
    if (o == UIDeviceOrientationUnknown) return MPInterfaceOrientation();
    return o;
}

- (void)useCustomClose:(BOOL)shouldUseCustomClose {
    switch (_closeButtonStyle) {
        case MRAdViewCloseButtonStyleAdControlled:
            self.view.usesCustomCloseButton = shouldUseCustomClose;
            break;
        case MRAdViewCloseButtonStyleAlwaysHidden:
            self.view.usesCustomCloseButton = YES;
            break;
        case MRAdViewCloseButtonStyleAlwaysVisible:
            self.view.usesCustomCloseButton = NO;
        default:
            break;
    }
    
    [_view adDidRequestCustomCloseEnabled:shouldUseCustomClose];
}

#pragma mark - Expand Helpers

- (void)saveCurrentViewTransform {
    _originalTransform = self.view.transform;
}

- (void)restoreOriginalViewTransform {
    self.view.transform = _originalTransform;
}

- (void)applyRotationTransformForCurrentOrientationOnView:(UIView *)view {
    // We need to rotate the ad view in the direction opposite that of the device's rotation.
    // For example, if the device is in LandscapeLeft (90 deg. clockwise), we have to rotate
    // the view -90 deg. counterclockwise.
    
    CGFloat angle = 0.0;
    
    switch (self.orientationForExpandedView) {
        case UIInterfaceOrientationPortraitUpsideDown: angle = M_PI; break;
        case UIInterfaceOrientationLandscapeLeft: angle = -M_PI_2; break;
        case UIInterfaceOrientationLandscapeRight: angle = M_PI_2; break;
        default: break;
    }
    
    view.transform = CGAffineTransformMakeRotation(angle);
}

- (void)assignRandomTagToDefaultSuperview {
    _originalTag = self.view.superview.tag;
    do {
        _parentTag = arc4random() % 25000;
    } while ([MPKeyWindow() viewWithTag:_parentTag]);
    
    self.view.superview.tag = _parentTag;
}

- (void)restoreDefaultSuperviewTag {
    [[MPKeyWindow() viewWithTag:_parentTag] setTag:_originalTag];
}

- (void)moveViewFromDefaultSuperviewToWindow {
    [self saveCurrentViewTransform];
    [self applyRotationTransformForCurrentOrientationOnView:self.view];
    [self assignRandomTagToDefaultSuperview];
    
    // Add the ad view as a subview of the window. This requires converting the ad view's frame from
    // its superview's coordinate system to that of the window.
    UIWindow *keyWindow = MPKeyWindow();
    _defaultFrameInKeyWindow = [self.view.superview convertRect:_defaultFrame toView:keyWindow];
    self.view.frame = _defaultFrameInKeyWindow;
    
    [keyWindow addSubview:self.view];
}

- (void)moveViewFromWindowToDefaultSuperview {
    UIView *defaultSuperview = [MPKeyWindow() viewWithTag:_parentTag];
    [defaultSuperview addSubview:self.view];
    
    [self restoreDefaultSuperviewTag];
    [self restoreOriginalViewTransform];
}

- (void)animateViewFromDefaultStateToExpandedState:(UIView *)view {
    // Calculate the expanded ad's frame in window coordinates.
    CGRect expandedFrameInWindow = [self convertRectToWindowForCurrentOrientation:_expandedFrame];
    
    // Begin animating to the expanded state.
    [UIView beginAnimations:kAnimationKeyExpand context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    
    [_dimmingView setDimmed:YES];
    _expansionContentView.frame = expandedFrameInWindow;
    
    [UIView commitAnimations];
    
    // Note: view and JS state changes will be done in animationDidStop:finished:context:.
}

- (void)hideExpandedElementsIfNeeded {
    if (_currentState == MRAdViewStateExpanded) {
        self.view.hidden = YES;
        _dimmingView.hidden = YES;
    }
}

- (void)unhideExpandedElementsIfNeeded {
    if (_currentState == MRAdViewStateExpanded) {
        self.view.hidden = NO;
        _dimmingView.hidden = NO;
    }
}

- (void)rotateExpandedWindowsToCurrentOrientation {
    // This method must have no effect if our ad isn't expanded.
    if (_currentState != MRAdViewStateExpanded) return;
    BOOL forcedOrientation = (_view.forceExpandedOrientation != UIDeviceOrientationUnknown);
    
    UIApplication *application = [UIApplication sharedApplication];
    
    // Update the location of our default frame in window coordinates.
    CGRect _defaultFrameWithStatusBarOffset = _defaultFrame;
    if (!application.statusBarHidden) _defaultFrameWithStatusBarOffset.origin.y += 20;
    _defaultFrameInKeyWindow = 
        [self convertRectToWindowForCurrentOrientation:_defaultFrameWithStatusBarOffset];
    
    CGRect f = [UIScreen mainScreen].applicationFrame;
    CGPoint centerOfApplicationFrame = CGPointMake(CGRectGetMidX(f), CGRectGetMidY(f));
    
    if (!forcedOrientation) {
    [UIView beginAnimations:kAnimationKeyRotateExpanded context:nil];
    [UIView setAnimationDuration:0.3];
    }
    
    // Center the view in the application frame.
    _expansionContentView.center = centerOfApplicationFrame;
    
    [self constrainViewBoundsToApplicationFrame];
    [self applyRotationTransformForCurrentOrientationOnView:_expansionContentView];
    
    if (!forcedOrientation)
    [UIView commitAnimations];
}
- (CGRect) applicationFrameForExpansionView
{
    if (_view.forceExpandedOrientation == UIDeviceOrientationUnknown) return MPApplicationFrame();
 	CGRect bounds = [UIScreen mainScreen].bounds;
	
	if (UIInterfaceOrientationIsLandscape(_view.forceExpandedOrientation))
	{
		CGFloat width = bounds.size.width;
		bounds.size.width = bounds.size.height;
		bounds.size.height = width;
	}
    
    
    return bounds;
   
}

- (void)constrainViewBoundsToApplicationFrame {
    CGFloat height = _expandedFrame.size.height;
    CGFloat width = _expandedFrame.size.width;
    
    CGRect applicationFrame = self.applicationFrameForExpansionView;
    
    if (height > CGRectGetHeight(applicationFrame)) height = CGRectGetHeight(applicationFrame);
    if (width > CGRectGetWidth(applicationFrame)) width = CGRectGetWidth(applicationFrame);
    
    _expansionContentView.bounds = CGRectMake(0, 0, width, height);
}

- (CGRect)orientationAdjustedRect:(CGRect)rect {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIInterfaceOrientation orientation = MPInterfaceOrientation();
    
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            rect.origin.y = keyWindow.frame.size.height - rect.origin.y - rect.size.height;
            rect.origin.x = keyWindow.frame.size.width - rect.origin.x - rect.size.width;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            rect = CGRectMake(keyWindow.frame.size.height - rect.origin.y - rect.size.height, 
                              rect.origin.x, 
                              rect.size.height, 
                              rect.size.width);
            break;
        case UIInterfaceOrientationLandscapeRight:
            rect = CGRectMake(rect.origin.y, 
                              keyWindow.frame.size.width - rect.origin.x - rect.size.width, 
                              rect.size.height, 
                              rect.size.width);
            break;
        default: break;
    }
    
    return rect;
}

- (CGRect)convertRectToWindowForCurrentOrientation:(CGRect)rect {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIInterfaceOrientation orientation = self.orientationForExpandedView;
    
    switch (orientation) {
        case UIInterfaceOrientationPortraitUpsideDown:
            rect.origin.y = keyWindow.frame.size.height - rect.origin.y - rect.size.height;
            rect.origin.x = keyWindow.frame.size.width - rect.origin.x - rect.size.width;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            rect = CGRectMake(rect.origin.y, 
                              keyWindow.frame.size.height - rect.origin.x - rect.size.width, 
                              rect.size.height, 
                              rect.size.width);
            break;
        case UIInterfaceOrientationLandscapeRight:
            rect = CGRectMake(keyWindow.frame.size.width - rect.origin.y - rect.size.height, 
                              rect.origin.x, 
                              rect.size.height, 
                              rect.size.width);
            break;
        default: break;
    }
    
    return rect;
}

#pragma mark -
#pragma mark UIView Animation Delegate

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished 
                 context:(void *)context {
    if ([animationID isEqualToString:kAnimationKeyExpand]) 
        [self expandAnimationDidStop];
    else if ([animationID isEqualToString:kAnimationKeyCloseExpanded]) 
        [self closeExpandAnimationDidStop];
}

- (void)expandAnimationDidStop {
    _currentState = MRAdViewStateExpanded;
    [_view fireChangeEventForProperty:[MRStateProperty propertyWithState:_currentState]];
    [_view adDidExpandToFrame:_expansionContentView.frame];
}

- (void)closeExpandAnimationDidStop {
    [self moveViewFromWindowToDefaultSuperview];
    [_dimmingView removeFromSuperview];
    self.view.frame = _defaultFrame;
    if (_expansionContentView != self.view)
        [_expansionContentView removeFromSuperview];
    
    _currentState = MRAdViewStateDefault;
    [_view fireChangeEventForProperty:[MRStateProperty propertyWithState:_currentState]];
    
    [_view adDidDismissModalView];
}

#pragma mark - Viewability Timer

- (void)checkViewability {
    BOOL currentViewability = [_view isViewable];
    
    if (_isViewable != currentViewability) {
        MPLogDebug(@"Viewable changed to: %@", currentViewability ? @"YES" : @"NO");
        _isViewable = currentViewability;
        [_view adViewableDidChange:_isViewable];
    }
}

#pragma mark -

- (void)closeButtonPressed {
    [self close];
}

- (void)revertViewToDefaultState {
    if (_currentState == MRAdViewStateDefault) return;
    
    [self close];
}

- (void)additionalModalViewWillPresent {
    [self hideExpandedElementsIfNeeded];
}

- (void)additionalModalViewDidDismiss {
    [self unhideExpandedElementsIfNeeded];
}

#pragma mark - MRAdViewDelegate for two-part expansion view

- (void) presentModalViewController: (UIViewController*) vc
{
    [_view.delegate presentModalViewController:vc];
}
- (void) dismissModalViewController: (UIViewController*) vc
{
    [_view.delegate dismissModalViewController:vc];
}


    // This is really not needed - it gets notified twice and crashes the app.
//- (void)adDidClose:(MRAdView *)adView {
//    if (self.twoPartExpansionView == adView) return;
//    [self close];
//}

#pragma mark - Movie Player Notifications

- (void)moviePlayerWillEnterFullscreen:(NSNotification *)notification {
    [self hideExpandedElementsIfNeeded];
}

- (void)moviePlayerDidExitFullscreen:(NSNotification *)notification {
    [self unhideExpandedElementsIfNeeded];
}

@end
