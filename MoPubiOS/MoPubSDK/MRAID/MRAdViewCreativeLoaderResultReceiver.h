//
//  MRAdViewCreativeLoaderResultReceiver.h
//  talk-me
//
//  Created by Vadim Tsyganok on 11/13/12.
//  Copyright (c) 2012 talkme.im. All rights reserved.
//

#ifndef talk_me_MRAdViewCreativeLoaderResultReceiver_h
#define talk_me_MRAdViewCreativeLoaderResultReceiver_h

    // receiver of creative for custom ad loaders. Pass nil as html to indicate failure.
typedef void (^MRAdViewCreativeLoaderResultReceiver)(NSURL* url, NSString* html);


#endif
