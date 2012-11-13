//
//  MRAdHTMLRequest.h
//  talk-me
//
//  Created by Vadim Tsyganok on 11/12/12.
//  Copyright (c) 2012 talkme.im. All rights reserved.
//

#import <Foundation/Foundation.h>
@class MRAdHTMLRequest;

@protocol MRAdHTMLRequestDelegate <NSObject>

@required
- (void) htmlRequest: (MRAdHTMLRequest*) request didCompleteWithData: (NSData*) data;
- (void) htmlRequest: (MRAdHTMLRequest*) request didFailWithError: (NSError*) error;

@end

@interface MRAdHTMLRequest : NSObject
{
    NSURLRequest* originalRequest;
    NSURLConnection* conn;
    NSMutableData* data;
    NSObject<MRAdHTMLRequestDelegate>* delegate;
}

@property (nonatomic, readonly) NSURLRequest* originalRequest;
@property (nonatomic, readonly) NSData* data;
- (id) initWithRequest: (NSURLRequest*) request andDelegate: (NSObject<MRAdHTMLRequestDelegate>*) aDelegate;

@end
