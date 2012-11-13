//
//  MRCommand.m
//  MoPub
//
//  Created by Andrew He on 12/19/11.
//  Copyright (c) 2011 MoPub, Inc. All rights reserved.
//

#import "MRCommand.h"
#import "MRAdView.h"
#import "MRAdViewBrowsingController.h"
#import "MRAdViewDisplayController.h"
#import "MPGlobal.h"
#import "MPLogging.h"
#import <objc/runtime.h>
#include <time.h>
#include <xlocale.h>
#import <EventKit/EventKit.h>
#import <MessageUI/MessageUI.h>

@implementation MRCommand

@synthesize view = _view;
@synthesize parameters = _parameters;

+ (NSMutableDictionary *)sharedCommandClassMap {
    static NSMutableDictionary *sharedMap = nil;
    @synchronized(self) {
        if (!sharedMap) sharedMap = [[NSMutableDictionary alloc] init];
    }
    return sharedMap;
}

+ (void)registerCommand:(Class)commandClass {
    NSMutableDictionary *map = [self sharedCommandClassMap];
    @synchronized(self) {
        [map setValue:commandClass forKey:[commandClass commandType]];
    }
}

+ (NSString *)commandType {
    return @"BASE_CMD_TYPE";
}

+ (Class)commandClassForString:(NSString *)string {
    NSMutableDictionary *map = [self sharedCommandClassMap];
    @synchronized(self) {
        return [map objectForKey:string];
    }
}

+ (id)commandForString:(NSString *)string {
    Class commandClass = [self commandClassForString:string];
    return [[[commandClass alloc] init] autorelease];
}

- (void)dealloc {
    [_parameters release];
    [super dealloc];
}

- (BOOL)execute {
    return YES;
}

- (CGFloat)floatFromParametersForKey:(NSString *)key {
    return [self floatFromParametersForKey:key withDefault:0.0];
}

- (CGFloat)floatFromParametersForKey:(NSString *)key withDefault:(CGFloat)defaultValue {
    NSString *stringValue = [self.parameters valueForKey:key];
    return stringValue ? [stringValue floatValue] : defaultValue;
}

- (BOOL)boolFromParametersForKey:(NSString *)key {
    NSString *stringValue = [self.parameters valueForKey:key];
    return [stringValue isEqualToString:@"true"];
}

- (int)intFromParametersForKey:(NSString *)key {
    NSString *stringValue = [self.parameters valueForKey:key];
    return stringValue ? [stringValue intValue] : -1;
}

- (NSString *)stringFromParametersForKey:(NSString *)key {
    NSString *value = [self.parameters objectForKey:key];
    if (!value || [value isEqual:[NSNull null]]) return nil;
    
    value = [value stringByTrimmingCharactersInSet:
             [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!value || [value isEqual:[NSNull null]] || value.length == 0) return nil;
    
    return value;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MRCloseCommand

+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"close";
}

- (BOOL)execute {
    [self.view.displayController close];
    return YES;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MRExpandCommand

+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"expand";
}

- (BOOL)execute {
    CGRect applicationFrame = MPApplicationFrame();
    CGFloat afWidth = CGRectGetWidth(applicationFrame);
    CGFloat afHeight = CGRectGetHeight(applicationFrame);
    
    // If the ad has expandProperties, we should use the width and height values specified there.
	CGFloat w = [self floatFromParametersForKey:@"w" withDefault:afWidth];
	CGFloat h = [self floatFromParametersForKey:@"h" withDefault:afHeight];
    
    // Constrain the ad to the application frame size.
    if (w > afWidth) w = afWidth;
    if (h > afHeight) h = afHeight;
    
    // Center the ad within the application frame.
    CGFloat x = applicationFrame.origin.x + floor((afWidth - w) / 2);
    CGFloat y = applicationFrame.origin.y + floor((afHeight - h) / 2);
	
	NSString *urlString = [self stringFromParametersForKey:@"url"];
	NSURL *url = [NSURL URLWithString:urlString];
    
	MPLogDebug(@"Expanding to (%.1f, %.1f, %.1f, %.1f); displaying %@.", x, y, w, h, url);
    
	CGRect newFrame = CGRectMake(x, y, w, h);
    
    [self.view.displayController expandToFrame:newFrame 
                           withURL:url 
                    useCustomClose:[self boolFromParametersForKey:@"shouldUseCustomClose"]
                           isModal:NO
             shouldLockOrientation:[self boolFromParametersForKey:@"lockOrientation"]];
    return YES;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MRUseCustomCloseCommand

+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"usecustomclose";
}

- (BOOL)execute {
    BOOL shouldUseCustomClose = [[self.parameters valueForKey:@"shouldUseCustomClose"] boolValue];
    [self.view.displayController useCustomClose:shouldUseCustomClose];
    return YES;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation MROpenCommand

+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"open";
}

- (BOOL)execute {
    NSString *URLString = [self stringFromParametersForKey:@"url"];
    [self.view.browsingController openBrowserWithUrlString:URLString
                                                enableBack:YES
                                             enableForward:YES
                                             enableRefresh:YES];
    return YES;
}

@end

@implementation MRStorePictureCommand
+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"storePicture";
}
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error)
    {
        UIAlertView *alert = [[UIAlertView alloc]
                              initWithTitle: @"Save failed"
                              message: [NSString stringWithFormat:@"Failed to save image:\n%@", error]
                              delegate: nil
                              cancelButtonTitle:@"OK"
                              otherButtonTitles:nil];
        
        [alert show];
        [alert release];
    }
}
- (BOOL)execute {
    NSString *URLString = [self stringFromParametersForKey:@"url"];
    
    UIImage* image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:URLString]]];
    
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    
    return YES;
}

@end

@implementation MRCreateCalendarEventCommand
+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"createEvent";
}

static NSCharacterSet* tzMarkerCharacterSet = nil;

    // Expects something like: 2012-12-21T10:30:15-0500
+ (id)dateFromW3CCalendarDate:(NSString*)dateString
{
    if (tzMarkerCharacterSet == nil)
        tzMarkerCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"+-"];
    
    if ([dateString length] == 0)
        return nil;
    
        // Needs to have a date and time.
    NSArray* dateAndTime = [dateString componentsSeparatedByString:@"T"];
    if ([dateAndTime count] != 2)
        return nil;
    
    NSString* time = [dateAndTime objectAtIndex:1];
    if ([time hasSuffix:@"Z"])
    {
            // Swap Z for the GMT offset.
        time = [time stringByReplacingOccurrencesOfString:@"Z" withString:@"+0000"];
    }
    else
    {
        NSRange tzMarker = [time rangeOfCharacterFromSet:tzMarkerCharacterSet];
        if (tzMarker.location != NSNotFound)
        {
                // Remove the : from the zone offset.
            NSString* zone = [time substringFromIndex:tzMarker.location];
            NSString* fixedZone = [zone stringByReplacingOccurrencesOfString:@":" withString:@""];
            
            time = [time stringByReplacingOccurrencesOfString:zone withString:fixedZone];
            
                // Add in zero'd seconds if seconds are missing.
            if ([[time componentsSeparatedByString:@":"] count] < 3)
            {
                tzMarker.length = 0;
                time = [time stringByReplacingCharactersInRange:tzMarker withString:@":00"];
            }
        }
        else
        {
                // Add a GMT offset so "something" is there.
            time = [time stringByAppendingString:@"+0000"];
        }
    }
    
    NSString* fixedDateString = [NSString stringWithFormat:@"%@T%@",
                                 [dateAndTime objectAtIndex:0],
                                 time];
    
    struct tm parsedTime;
    const char* formatString = "%FT%T%z";
    strptime_l([fixedDateString UTF8String], formatString, &parsedTime, NULL);
    time_t since = mktime(&parsedTime);
    
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:since];
    
    return date;
}

- (BOOL)execute {
    NSString* dateString = [self stringFromParametersForKey:@"date"];
    NSString* title = [self stringFromParametersForKey:@"title"];
    NSString* body = [self stringFromParametersForKey:@"body"];
    
    
    NSDate* start = [MRCreateCalendarEventCommand dateFromW3CCalendarDate:dateString];
    NSDate* end = [start dateByAddingTimeInterval:3600];
    
    
    EKEventStore* store = [[EKEventStore alloc] init];
    EKEvent* event = [EKEvent eventWithEventStore:store];
    
    event.startDate = start;
    event.endDate = end;
    event.title = title;
    event.notes = body;
    
    [store saveEvent:event span:EKSpanThisEvent error:nil];
    
    return YES;
}

@end

@interface MRSendMailCommand(Private)<MFMailComposeViewControllerDelegate>
@end

@implementation MRSendMailCommand
+ (void)load {
    [MRCommand registerCommand:self];
}

+ (NSString *)commandType {
    return @"sendMail";
}

- (BOOL)execute {
    if (!MFMailComposeViewController.canSendMail) return NO;
        // sendMail(recipient, subject, body)
    NSString* recipient = [self stringFromParametersForKey:@"recipient"];
    NSString* subject = [self stringFromParametersForKey:@"subject"];
    NSString* body = [self stringFromParametersForKey:@"body"];
    
    MFMailComposeViewController* mail = [[MFMailComposeViewController alloc] init];
    
    [mail setToRecipients:[NSArray arrayWithObject:recipient]];
    if (body.length)
        [mail setMessageBody:body isHTML:NO];
    if (subject.length)
        [mail setSubject:subject];
    
    [self.view.delegate presentModalViewController:mail];
    
    [mail release];
    
    return YES;
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self.view.delegate dismissModalViewController:controller];
}

@end
