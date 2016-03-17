/*///////////////////////////////////////////////////////////////////
 GNU PUBLIC LICENSE - The copying permission statement
 --------------------------------------------------------------------
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 ///////////////////////////////////////////////////////////////////*/

//
//  DMModepromptManager.m
//  DataMobile
//
//  Created by Takeshi MUKAI on 12/21/15.
//  Copyright (c) 2015 MML-Concordia. All rights reserved.
//

#import "DMModepromptManager.h"
#import "DMAppDelegate.h"

@implementation DMModepromptManager
@synthesize delegate;
@synthesize alertViewConfirm, alertViewModeTravel, alertViewPurpose;
@synthesize strModeTravel;

// this is called from DMEfficientLocationManger, and from DMAppDelegate
// it should be called twice? because to show alertView when it is called from both of DMEfficientLocationManger and DMAppDelegate
- (void)allocModepromptAlertView
{
    alertViewConfirm = [[UIAlertView alloc] init];
    alertViewConfirm.tag = 0;
    alertViewConfirm.delegate = self;
    alertViewConfirm.title = @"You've stopped.";
    alertViewConfirm.message = @"Have you reached your destination?";
    [alertViewConfirm addButtonWithTitle:@"No"];
    [alertViewConfirm addButtonWithTitle:@"Yes"];
    
    alertViewModeTravel = [[UIAlertView alloc] init];
    alertViewModeTravel.tag = 1;
    alertViewModeTravel.delegate = self;
    alertViewModeTravel.title = @"How did you get here?";
    alertViewModeTravel.message = nil;
    [alertViewModeTravel addButtonWithTitle:@"Bike"];
    [alertViewModeTravel addButtonWithTitle:@"Bus"];
    [alertViewModeTravel addButtonWithTitle:@"Car"];
    [alertViewModeTravel addButtonWithTitle:@"Metro"];
    [alertViewModeTravel addButtonWithTitle:@"Train"];
    [alertViewModeTravel addButtonWithTitle:@"Walk"];
    [alertViewModeTravel addButtonWithTitle:@"Car and Transit"];
    [alertViewModeTravel addButtonWithTitle:@"Cancel/Not at Destination"];
    
    alertViewPurpose = [[UIAlertView alloc] init];
    alertViewPurpose.tag = 2;
    alertViewPurpose.delegate = self;
    alertViewPurpose.title = @"Why did you make this trip?";
    alertViewPurpose.message = nil;
    [alertViewPurpose addButtonWithTitle:@"Work"];
    [alertViewPurpose addButtonWithTitle:@"Business Meeting"];
    [alertViewPurpose addButtonWithTitle:@"Education"];
    [alertViewPurpose addButtonWithTitle:@"Shopping"];
    [alertViewPurpose addButtonWithTitle:@"Leisure"];
    [alertViewPurpose addButtonWithTitle:@"Health"];
    [alertViewPurpose addButtonWithTitle:@"Pick-up/Drop-off Someone"];
    [alertViewPurpose addButtonWithTitle:@"Return Home"];
    [alertViewPurpose addButtonWithTitle:@"Other"];
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag==0) {
        switch (buttonIndex) {
            case 0:
                break;
            case 1:
                [alertViewModeTravel show];
                break;
        }
    }else if (alertView.tag==1) {
        switch (buttonIndex) {
            case 0:
                [self insertModepromptTravel:@"Bike"];
                break;
            case 1:
                [self insertModepromptTravel:@"Bus"];
                break;
            case 2:
                [self insertModepromptTravel:@"Car"];
                break;
            case 3:
                [self insertModepromptTravel:@"Metro"];
                break;
            case 4:
                [self insertModepromptTravel:@"Train"];
                break;
            case 5:
                [self insertModepromptTravel:@"Walk"];
                break;
            case 6:
                [self insertModepromptTravel:@"Car and Transit"];
                break;
            case 7:
                break;
        }
    }else if (alertView.tag==2) {
        switch (buttonIndex) {
            case 0:
                [self insertModepromptPurpose:@"Work"];
                break;
            case 1:
                [self insertModepromptPurpose:@"Business Meeting"];
                break;
            case 2:
                [self insertModepromptPurpose:@"Education"];
                break;
            case 3:
                [self insertModepromptPurpose:@"Shopping"];
                break;
            case 4:
                [self insertModepromptPurpose:@"Leisure"];
                break;
            case 5:
                [self insertModepromptPurpose:@"Health"];
                break;
            case 6:
                [self insertModepromptPurpose:@"Pick-up/Drop-off Someone"];
                break;
            case 7:
                [self insertModepromptPurpose:@"Return Home"];
                break;
            case 8:
                [self insertModepromptPurpose:@"Other"];
                break;
        }
    }
}

// this is called from DMEfficientLocationManger - when stopped
- (void)readyModeprompt:(CLLocation*)lastLocation
{
    lastPromptedLocation = lastLocation;
    isModeprompting = YES;
    
    // if app is active(foreground), it will show alertViewConfirm, (or alertViewConfirm depends on notification)
    UIApplicationState applicationState = [[UIApplication sharedApplication] applicationState];
    if (applicationState == UIApplicationStateActive) {
        [self showAlertViewConfirm];
    }
    
    // set local notification instantly
    [self setLocalNotificationModeprompt:0];
}

// show AlerViewConfirm
// it is also called from DMAppDelegate when app becomes foreground - to show alertview if app becomes foreground without touching nitification
- (void)showAlertViewConfirm
{
    if (isModeprompting) {
        // delete all from notificationCenter
        if (!isDebugLogEnabled) {
            [[UIApplication sharedApplication] cancelAllLocalNotifications];
        }
        [alertViewConfirm show];
        isModeprompting = NO;
    }
}

// from DMAppDelegate - with notification
- (void)dealModepromptFromNotif:(BOOL)isShowModeTravel travelMode:(NSString*)modeTravel
{
    // hide (not showing) alertViewConfirm
    isModeprompting = NO;
    
    if (isShowModeTravel) {
        // will show alerViewModeTravel directly
        [alertViewModeTravel show];
    }else{
        if (modeTravel) {
            // record travelMode from notification
            [self insertModepromptTravel:modeTravel];
        }
    }
}

// insert modeprompt travel
- (void)insertModepromptTravel:(NSString*)modeTravel
{
    // set modeTravel
    strModeTravel = modeTravel;
    
    // show alertViewPurpose
    [alertViewPurpose show];
}

// insert modeprompt, delegate to DMLocationManager
- (void)insertModepromptPurpose:(NSString*)purpose
{
    [delegate insertModeprompt:lastPromptedLocation travelMode:strModeTravel purpose:purpose];
}

- (void)setLocalNotificationModeprompt:(NSTimeInterval)interval
{
    // set local notification for Modeprompt
    // cancel all notifications first
    // delete all from notificationCenter first
    if (!isDebugLogEnabled) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    }
    
    // set localNotification
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    localNotification.timeZone = [NSTimeZone defaultTimeZone];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    
    localNotification.alertBody = @"You've stopped.\nHave you reached your destination?";
    localNotification.alertAction = @"Open";
    // if iOS8 or above
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        localNotification.category = @"INVITE_CATEGORY";
    }
    
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}


@end
