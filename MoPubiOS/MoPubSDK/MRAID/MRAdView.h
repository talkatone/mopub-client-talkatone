//
//  MRAdView.h
//  MoPub
//
//  Created by Andrew He on 12/20/11.
//  Copyright (c) 2011 MoPub, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MRAdViewCreativeLoaderResultReceiver.h"
@class MRAdViewBrowsingController, MRAdViewDisplayController, MRProperty;
@protocol MRAdViewDelegate;
@protocol MRAdViewCreativeLoader;
enum {
    MRAdViewStateHidden = 0,
    MRAdViewStateDefault = 1,
    MRAdViewStateExpanded = 2
};
typedef NSUInteger MRAdViewState;

enum {
    MRAdViewPlacementTypeInline,
    MRAdViewPlacementTypeInterstitial
};
typedef NSUInteger MRAdViewPlacementType;

enum {
    MRAdViewCloseButtonStyleAlwaysHidden,
    MRAdViewCloseButtonStyleAlwaysVisible,
    MRAdViewCloseButtonStyleAdControlled
};
typedef NSUInteger MRAdViewCloseButtonStyle;

@interface MRAdView : UIView <UIWebViewDelegate> {
    // This view's delegate object.
    id<MRAdViewDelegate> _delegate;
    
    // The underlying webview.
    UIWebView *_webView;
    
    // The native close button, shown when this view is used as an interstitial ad, or when the ad
    // is expanded.
    UIButton *_closeButton;
    
//    // Stores the HTML payload of a creative, when loading a creative from an NSURL.
//    NSMutableData *_data;
    
    // Performs in-app browser-related actions.
    MRAdViewBrowsingController *_browsingController;
    
    // Performs display-related actions, such as expanding and closing the ad.
    MRAdViewDisplayController *_displayController;
    
    // Flag indicating whether this view is currently loading an ad.
    BOOL _isLoading;
    
    // The number of modal views this ad has presented.
    NSInteger _modalViewCount;
    
    // Flag indicating whether this view's ad content provides its own custom (non-native) close
    // button.
    BOOL _usesCustomCloseButton;
    
    MRAdViewCloseButtonStyle _closeButtonStyle;
    
    // Flag indicating whether ads presented in this view are allowed to use the expand() API.
    BOOL _allowsExpansion;
    
    BOOL _expanded;
    
    // Enum indicating whether this view is being used as an inline ad or an interstitial ad.
    MRAdViewPlacementType _placementType;
    
    // Forced orientation of expansion overlay
    UIInterfaceOrientation _forceExpandedOrientation;
    BOOL _hideStatusBarWhenExpanded;
    
    NSURL* _overridenOverlayUrl;
}

@property (nonatomic, assign) id<MRAdViewDelegate> delegate;
@property (nonatomic, assign) id<MRAdViewCreativeLoader> creativeLoader;
@property (nonatomic, assign) BOOL usesCustomCloseButton;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, assign) UIInterfaceOrientation forceExpandedOrientation;
@property (nonatomic, assign) BOOL hideStatusBarWhenExpanded;
@property (nonatomic, retain) NSURL* overridenOverlayUrl;
    // Expansion view (if created). may be the same (for one-part ads) or different for 2-part ads:
@property (nonatomic, readonly) MRAdView* expansionView;

- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame allowsExpansion:(BOOL)expansion 
   closeButtonStyle:(MRAdViewCloseButtonStyle)style placementType:(MRAdViewPlacementType)type;
- (void)loadCreativeFromURL:(NSURL *)url;
- (void)loadCreativeWithHTMLString:(NSString *)html baseURL:(NSURL *)url;
- (NSString *)executeJavascript:(NSString *)javascript, ...;
- (BOOL)isViewable;
- (void)rotateToOrientation:(UIInterfaceOrientation)newOrientation;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol MRAdViewDelegate <NSObject>

@required

// Retrieves the view controller from which modal views should be presented.
- (void) presentModalViewController: (UIViewController*) vc;
- (void) dismissModalViewController: (UIViewController*) vc;


@optional

// Called when the ad loads successfully.
- (void)adDidLoad:(MRAdView *)adView;

// Called when the ad fails to load.
- (void)adDidFailToLoad:(MRAdView *)adView;

// Called just before the ad is displayed on-screen.
- (void)adWillShow:(MRAdView *)adView;

// Called just after the ad has been displayed on-screen.
- (void)adDidShow:(MRAdView *)adView;

// Called just before the ad is hidden.
- (void)adWillHide:(MRAdView *)adView;

// Called just after the ad has been hidden.
- (void)adDidHide:(MRAdView *)adView;

// Called just before the ad expands.
- (void)willExpandAd:(MRAdView *)adView
			 toFrame:(CGRect)frame;

// Called just after the ad has expanded.
- (void)didExpandAd:(MRAdView *)adView
			toFrame:(CGRect)frame;

// Called just before the ad closes.
- (void)adWillClose:(MRAdView *)adView;

// Called just after the ad has closed.
- (void)adDidClose:(MRAdView *)adView;

- (void)ad:(MRAdView *)adView didRequestCustomCloseEnabled:(BOOL)enabled;

// Called when the ad is about to display modal content (thus taking over the screen).
- (void)appShouldSuspendForAd:(MRAdView *)adView;

// Called when the ad has dismissed any modal content (removing any on-screen takeovers).
- (void)appShouldResumeFromAd:(MRAdView *)adView;

@end


@protocol MRAdViewCreativeLoader<NSObject>

@required
- (void) loadCreativeAt: (NSURL*) url for: (MRAdView*) ad to: (MRAdViewCreativeLoaderResultReceiver) receiver;

@end
