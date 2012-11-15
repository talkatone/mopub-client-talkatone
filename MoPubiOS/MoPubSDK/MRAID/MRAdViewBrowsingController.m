//
//  MRAdViewBrowsingController.m
//  MoPub
//
//  Created by Andrew He on 12/22/11.
//  Copyright (c) 2011 MoPub, Inc. All rights reserved.
//

#import "MRAdViewBrowsingController.h"
#import "MRAdView.h"
#import "MRAdView+Controllers.h"

@implementation MRAdViewBrowsingController

- (id)initWithAdView:(MRAdView *)adView {
    self = [super init];
    if (self) {
        _view = adView;
    }
    return self;
}

- (void)openBrowserWithUrlString:(NSString *)urlString enableBack:(BOOL)back
                   enableForward:(BOOL)forward enableRefresh:(BOOL)refresh {
    NSURL *url = [NSURL URLWithString:urlString];
    MPAdBrowserController *controller = [[MPAdBrowserController alloc] initWithURL:url 
                                                                          delegate:self];
    
    [_view adWillPresentModalView];
    [_view.delegate presentModalViewController:controller];
    [controller startLoading];
    [controller release];
}

#pragma mark -
#pragma mark MPAdBrowserControllerDelegate

- (void)dismissBrowserController:(MPAdBrowserController *)browserController {
    [self dismissBrowserController:browserController animated:YES];
}

- (void)dismissBrowserController:(MPAdBrowserController *)browserController 
                        animated:(BOOL)animated {
    [_view.delegate dismissModalViewController:browserController];
    //[_view adWillShow];
    [_view adDidDismissModalView];
    //[_view adDidShow];
}

@end
