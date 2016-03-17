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
//  DMEfficientLocationManager.m
//  DataMobile
//
//  Created by Colin Rofls on 2014-07-22.
//  Copyright (c) 2014 MML-Concordia. All rights reserved.
//

//
//  MyLocationManager.m
//  DataMobile
//
//  Created by Kim Sawchuk on 11-11-28.
//  Copyright (c) 2011 MML-Concordia. All rights reserved.
//

// Modified by MUKAI Takeshi in 2015-08


#import "DMEfficientLocationManager.h"
#import "DMAppDelegate.h"  // Modified by MUKAI Takeshi in 2015-11


@interface DMEfficientLocationManager ()
{
    UIBackgroundTaskIdentifier bgTask;
}

@property (strong, nonatomic) CLLocation* lastLocation;
@property (strong, nonatomic) CLLocation* bestBadLocation;
@property (strong, nonatomic) CLCircularRegion* movingRegion;
@property (strong, nonatomic) NSTimer* wifiTimer;
@property (nonatomic) BOOL isGps;
@property (nonatomic) BOOL isMonitoringForRegionExit;

// Modified by MUKAI Takeshi in 2015-08
@property (strong, nonatomic) CLLocation* updatedNewLocation;  // for updateLocations
@property (strong, nonatomic) NSTimer* bBadLocationTimer;  // to record bestLocation in bestBadLocation
@property (strong, nonatomic) NSTimer* appTerminatedTimer;  // for ready to update location and create region on app terminated
@property (strong, nonatomic) CLLocation* bestBadLocationForRegion;

@end


@implementation DMEfficientLocationManager

/**
 The minimum amount of time the location service will be running in GPS mode.
 */
static const NSTimeInterval GPS_SWITCH_THRESHOLD = 60 * 2;
/**
 The value to set the location manager desiredAccuracy in GPS mode.
 */
static const int MIN_HORIZONTAL_ACCURACY = 30;
/**
 The minimum required distance between new location and last location.
 */
static const int MIN_DISTANCE_BETWEEN_POINTS = 30;

#define DM_MONITORED_REGION_RADIUS 100.0
#define DM_MONITORED_REGION_RADIUS_BBAD_MIN 150.0
#define DM_MONITORED_REGION_RADIUS_BBAD_MAX 500.0

// Modified by MUKAI Takeshi
static const NSTimeInterval BBAD_RECORD_TIMER = 60 * 1;
static const int BBAD_MIN_HORIZONTAL_ACCURACY = 100;
static const int BBAD_MAX_HORIZONTAL_ACCURACY = 1600;
static const NSTimeInterval APP_TERMINATED_TIMER = 160;
#define DM_MONITORED_REGION_RADIUS_ON_APP_TERMINATED_MIN 5.0
#define DM_MONITORED_REGION_RADIUS_ON_APP_TERMINATED_MAX 30.0
#define DM_MODEPROMPT_THRESHOLD_ON_APP_TERMINATED 2

@synthesize modepromptManager;
@synthesize debugLogView;


+ (CLCircularRegion *)regionWithCenter:(CLLocationCoordinate2D)coordinate
                       radius:(CLLocationDistance)radius
                   identifier:(NSString *)identifier
{
    if ([CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
        return  [[CLCircularRegion alloc] initWithCenter:coordinate
                                                  radius:radius
                                              identifier:identifier];
    }
    return nil;
}

- (id)init
{
    if(self == [super init])
    {
//        if([CLLocationManager authorizationStatus] != kCLAuthorizationStatusAuthorized)
//        {
//            DDLogWarn(@"LOCATION IS NOT AUTHORIZED");
//        }
//        if([[UIApplication sharedApplication] backgroundRefreshStatus] != UIBackgroundRefreshStatusAvailable)
//        {
//            DDLogWarn(@"BACKGROUND REFRESH IS NOT AVAILBLE");
//        }
    }
    return self;
}

// alloc DMModeptomptManager
- (void)allocDMModepromptManager
{
    modepromptManager = [[DMModepromptManager alloc] init];
    modepromptManager.delegate = self;
    [modepromptManager allocModepromptAlertView];
}

// alloc DMdebugLogView
- (void)allocDMDebugLogView
{
    UIWindow* window = [[UIApplication sharedApplication] keyWindow];
    debugLogView = [[DMDebugLogViewController alloc] initWithNibName:@"DMDebugLogViewController" bundle:nil];
    debugLogView.view.frame = CGRectMake(120, 110, 200, 40);
    [window.rootViewController.view addSubview:debugLogView.view];
}

// startDMLocatinoManager - this is called from DMMainView when its viewDidLoad
- (void)startDMLocatinoManager {
    
    // for ready to update location and create region on app terminated
    if (isAppTerminated) {
        [self readyOnAppTerminated];
    }
    
    // notification observer
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    // for DMDebugLogView
    if (isDebugLogEnabled) {
        // alloc DMDebugLogView
        [self performSelectorOnMainThread:@selector(allocDMDebugLogView) withObject:nil waitUntilDone:NO];
    }
    
    // alloc DMModeptomptManager
    [self performSelectorOnMainThread:@selector(allocDMModepromptManager) withObject:nil waitUntilDone:NO];
    
    // set locationManager property
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = 25; // a relic, we should probably be using apple supplied values
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.pausesLocationUpdatesAutomatically = NO;
    // for iOS9, to update location in background  // Modified by MUKAI Takeshi in 2015-12
    // this is not ready in Xcode6
//    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 9.0) {
//        self.locationManager.allowsBackgroundLocationUpdates = YES;
//    }
    [self.locationManager startUpdatingLocation];
    
    // start GPS mode
    [self switchToGps];
}

// start standard location service
- (void)startUpdatingLocation {
    [self.locationManager startUpdatingLocation];
}

// stop standard location service
- (void)stopUpdatingLocation {
    [self.locationManager stopUpdatingLocation];
}


- (void)switchToGps
{
    // stop monitoringRegion
    [self.locationManager stopMonitoringForRegion:self.movingRegion];
    self.movingRegion = nil;
    // update viewContents - DMMainView - remove RegionOverlay
    [self.displayDelegate locationDataSourceStoppedMonitoringRegion];
    
    
    // for DMDebugLogView
    if (!isDebugLogEnabled) {
        // update viewContents - DMMainView - remove RegionOverlay
        [self.displayDelegate locationDataSourceStoppedMonitoringRegionOnAppTerminated];
    }
    
    
    // stop significant location
    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
    }
    
    // start GPS mode
    DDLogInfo(@"Location manager switched to Gps");
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;  // set AccuracyBest in GPS mode
    self.isGps = YES;
    [self resetWifiSwitchTimer];  // start timer for Wifi(region) mode
}

- (void)switchToWifiForRegion:(CLCircularRegion*)region
{
    if (!self.isGps) {
        DDLogError(@"switch to wifi called while !isGPS");
        NSAssert(self.isGps, @"switch to wifi should not be called if we aren't currently running on GPS");
    }
    
    // if we aren't given a region, switch to gps
    if (!region) {
        DDLogInfo(@"failed to acquire point");
        // This is called when app cannot get any locations after launched.
        // Turn on Gps mode, and then it will start from beginning
        [self switchToGps];
        return;
    }
    
    // Modified by MUKAI Takeshi in 2015-11
    // if region is created by wifiTimer - start wifi mode
    if ([region.identifier isEqualToString:@"movingRegion"]) {
        
        // to make Modeprompt alertView when stopped
        if (self.isGps && region) {
            // does not allow to make Modeprompt alertView when geofence created without moving(100m) since last time prompted
            CLLocationDistance deltaDistance = [lastPromptedLocation distanceFromLocation:self.lastLocation];
            if (deltaDistance>=DM_MONITORED_REGION_RADIUS) {
                // show alertview and set notification
                [modepromptManager readyModeprompt:self.lastLocation];
            }
        }
        
        // start Wifi mode
        DDLogInfo(@"Location manager switched to wifi");
        
        // stop significant location
        if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
            [self.locationManager stopMonitoringSignificantLocationChanges];
        }
        
        [self.wifiTimer invalidate];  // stop timer for Wifi(region) mode
        self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;  // set AccuracyThreeKilo in Wifi mode
        self.isGps = NO;
        
        // draw region overlay
        // for DMPointOptions
        self.isMonitoringForRegionExit = YES;
        //            mark previous location as involving a region change
        [self addOptionsToLastInsertedPoint:DMPointMonitorRegionStartPoint];
        
        // if regionMonitoring succeeded
        // update viewContents - DMMainView - set RegionOverlay
        [self.displayDelegate locationDataSource:self
              didStartMonitoringRegionWithCenter:region.center
                                          radius:region.radius];
        
        DDLogInfo(@"started monitoring for region %@ (%f, %f), radius %f",
                  region.identifier,
                  region.center.latitude,
                  region.center.longitude,
                  region.radius);
        
    }  // if region is created by onAppTerminated
    else if ([region.identifier isEqualToString:@"movingRegionOnAppTerminated"]) {
        // for modeprompt on app terminated "movinRegionOnAppTerminated", the notification will appear after 2min, if no new location updates
        if (self.isGps && region) {
            // does not allow to make Modeprompt alertView when geofence created without moving(100m) since last time prompted
            CLLocationDistance deltaDistance = [lastPromptedLocation distanceFromLocation:self.updatedNewLocation];
            if (deltaDistance>=DM_MONITORED_REGION_RADIUS) {
                if (!isModeprompting) {
                    // show alertview and set notification
                    [modepromptManager setLocalNotificationModeprompt:60*DM_MODEPROMPT_THRESHOLD_ON_APP_TERMINATED];
                }
            }
        }
    }
}

// this timer is used for switching between Gps and Wifi mode.
// keep reseting timer unless location keeps updating in Gps mode.
// so, if location doesn't update for a given time, it will swicth to Wifi mode
- (void)resetWifiSwitchTimer {
    [self.wifiTimer invalidate];
    self.wifiTimer = [NSTimer timerWithTimeInterval:GPS_SWITCH_THRESHOLD
                                             target:self
                                           selector:@selector(wifiTimerDidFire:)
                                           userInfo:nil
                                            repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.wifiTimer forMode:NSRunLoopCommonModes];
}

- (void)wifiTimerDidFire:(NSTimer*)timer {
    
    if (self.lastLocation) {
//        create a region to monitor based on last good location
        self.movingRegion = [DMEfficientLocationManager regionWithCenter:self.lastLocation.coordinate
                                                       radius:DM_MONITORED_REGION_RADIUS
                                                   identifier:@"movingRegion"];
    }
    else if (self.bestBadLocationForRegion.horizontalAccuracy<=BBAD_MAX_HORIZONTAL_ACCURACY && self.bestBadLocationForRegion) {
        // adjust region radius
        CLLocationDistance radius = [self adjustRegionRadius:self.bestBadLocationForRegion];
        //        if we don't have a good location, use our best _acceptable_ location.
        self.movingRegion = [DMEfficientLocationManager regionWithCenter:self.bestBadLocationForRegion.coordinate
                                                                  radius:radius
                                                              identifier:@"movingRegion"];
        DDLogInfo(@"no good points received, using larger geofence");
    }
    // bestBadLocationForRegion
    self.bestBadLocationForRegion = nil;
    
    if (self.movingRegion) {
        // if movionRegion is created, start monitoring region
        [self.locationManager startMonitoringForRegion:self.movingRegion];
        
        DDLogInfo(@"requesting state for region: %@", self.movingRegion);
        // "switchToWifiForRegion" will be called from state request
        //        if we have a region, find out if we're actually in it. Only monitor regions we're actually in.
        //        there's a bug in location manager where state requests will fail when executed immediately after a region is added:
        //        http://www.cocoanetics.com/2014/05/radar-monitoring-clregion-immediately-after-removing-one-fails/
        [self.locationManager performSelector:@selector(requestStateForRegion:) withObject:self.movingRegion afterDelay:1];
    }
    else{
        // if movingRegion isn't created
        [self switchToWifiForRegion:nil];
    }
}


#pragma mark - Application Lifecycle

- (void)applicationDidEnterBackground
{
    // for ready to update location and create region on app terminated
    // this should be called with applicationWillTerminate, but applicationWillTerminate will not called as in a case: foreground->background->terminated,
    // so this will be called with applicationDidEnterBackground
    [self createRegionOnAppTerminated];
    
    // set bgTask (for 3min)
    UIApplication* app = [UIApplication sharedApplication];
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
    
    // if significantLocation is available,
    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
        // the app quits by itself
        exit(0);
    }
}


#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"location manager did change status: %d", status);
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
//    we only want to monitor for exit of regions that we are actually in.
//    is this problematic? i.e., based on the fact that we only *set* region boundaries when our info has been bad for 2 mins?
//    probably not: our solution is problematic anyway. This *should* be a decent failsafe. But it requires some testing?
    NSString *stateDescription;
    switch (state) {
        case CLRegionStateInside:
            stateDescription = @"inside";
            break;
        case CLRegionStateOutside:
            stateDescription = @"outside";
            break;
        case CLRegionStateUnknown:
            stateDescription = @"unknown";
        default:
            break;
    }
    
    DDLogInfo(@"determined state: %@ for region %@", stateDescription, region);
    
    if (state == CLRegionStateInside) {
        [self switchToWifiForRegion:(CLCircularRegion*)region];
    }
    // Modified by MUKAI Takeshi
    else if (state == CLRegionStateOutside) {
        [self switchToGps];
    }
    // sometimes, the state will show as unknow. (in situations as no gps, no wifi, etc)
    // and in this case, app should act as same as StateInside, then it will switch to Wifi(Low energy) mode.
    else{  // state Unknown
        [self switchToWifiForRegion:(CLCircularRegion*)region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLCircularRegion *)region
{
    DDLogInfo(@"user entered %@", region.identifier);
    
    // for ready to update location and create region on app terminated
    if (isAppTerminated) {
        [self readyOnAppTerminated];
    }
    
    // for DMDebugLogView
    if (isDebugLogEnabled) {
        // set localNotification
        [debugLogView notifyDebugLog:@"didEnterRegion: " region:region location:self.updatedNewLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLCircularRegion *)region
{
    DDLogInfo(@"user exited %@", region.identifier);
    
    // for ready to update location and create region on app terminated
    if (isAppTerminated) {
        [self readyOnAppTerminated];
    }
    
    // for DMDebugLogView
    if (isDebugLogEnabled) {
        // set localNotification
        [debugLogView notifyDebugLog:@"didExitRegion: " region:region location:self.updatedNewLocation];
    }
    
    // switch to Gps mode and stop monitoringRegion
    [self switchToGps];
    
    // Modified by MUKAI Takeshi
    // to fix glitch, app should call a method in "(isGPS)didUpdateLocations", at this time.
    // so, I moved its method into "updateLocatinos", to call it from here.
    [self updateLocation];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    DDLogError(@"monitoring Did Fail For Region %@ with error %@", region.identifier ,error.localizedDescription);
    
    // for ready to update location and create region on app terminated
    if (isAppTerminated) {
        [self readyOnAppTerminated];
    }
    
    // for DMDebugLogView
    if (isDebugLogEnabled) {
        // set localNotification
        [debugLogView notifyDebugLog:@"FailForRegion: " region:region location:self.updatedNewLocation];
    }
}


#pragma mark - Standard and Significant Location Service - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    // for ready to update location and create region on app terminated
    if (isAppTerminated) {
        [self readyOnAppTerminated];
    }
    
    // Modified by MUKAI Takeshi
    self.updatedNewLocation = [locations lastObject];
    
    
    // for DMDebugLogView
    if (isDebugLogEnabled) {
        // show accuracy / updated
        [debugLogView showUpdated:self.updatedNewLocation];
        // set localNotification
        [debugLogView notifyDebugLog:@"didUpdateLocation " region:nil location:(CLLocation *)self.updatedNewLocation];
    }
    
    
    if (self.isGps) {
        // if Gps mode, updateLocation
        [self updateLocation];
        
    } else if (self.movingRegion) {
        //        if not GPS: this is our fallback. sometimes we don't seem to exit regions, so we're going
        //        to manually check and see if we seem to be far away from the region we're in, ostensibly.
        CLLocation *movingRegionLocation = [[CLLocation alloc]initWithLatitude:self.movingRegion.center.latitude
                                                                     longitude:self.movingRegion.center.longitude];
        CLLocationDistance deltaDistance = [movingRegionLocation distanceFromLocation:self.updatedNewLocation];
        if ((deltaDistance - self.updatedNewLocation.horizontalAccuracy) > 150) {
            DDLogInfo(@"received point likely outside of monitored region, switching to gps");
            [self switchToGps];
        }
    }
}

// Modified by MUKAI Takeshi
// this is called from "(isGPS)didUpdateLocations" or "didExitRegion"
- (void)updateLocation
{
    if (self.updatedNewLocation.horizontalAccuracy <= MIN_HORIZONTAL_ACCURACY) {
        
        // record updatedNewlocation
        [self recordLocation:self.updatedNewLocation];
    }
    else if (!self.bestBadLocation) {
        //            if our accuracy isn't any good
        self.bestBadLocation = self.updatedNewLocation;  // we may lose the chances to record bestBadLocation, however we shouldn't lose for the senstive area??? - we should fix - for example, even in bestBadLocation, if app will not be able to record the location around there at all, app should record bestBadLocation
        
        // Modified by MUKAI Takeshi
        // to record bestLocation in bestBadLocation
        if (!self.bBadLocationTimer) {
            self.bBadLocationTimer = [NSTimer scheduledTimerWithTimeInterval:BBAD_RECORD_TIMER target:self selector:@selector(setBBadLocation:) userInfo:nil repeats:NO];
        }
    }
    else if (self.updatedNewLocation.horizontalAccuracy < self.bestBadLocation.horizontalAccuracy) {
        self.bestBadLocation = self.updatedNewLocation;
    }
    
    [self resetWifiSwitchTimer];
}

// to record bestLocation in bestBadLocation
- (void)setBBadLocation:(NSTimer *)bBadLocationTimer
{
    // record bestBadlocation, if accrucacy is less than BBAD_MIN_HORIZONTAL_ACCURACY and not nil
    if (self.bestBadLocation.horizontalAccuracy<=BBAD_MIN_HORIZONTAL_ACCURACY && self.bestBadLocation) {
        [self recordLocation:self.bestBadLocation];
    }else{
        [self resetBBadLocation];
        // after resetting, put bestBadLocation into bestBadLocationForRegion
        self.bestBadLocationForRegion = self.bestBadLocation;
    }
}

// reset bBadLocationTimer and bBadLocation
- (void)resetBBadLocation
{
    if (self.bBadLocationTimer) {
        [self.bBadLocationTimer invalidate];
        self.bBadLocationTimer = nil;
        self.bestBadLocation = nil;
        self.bestBadLocationForRegion = nil;
    }
}

// to record location
- (void)recordLocation:(CLLocation*)newLocation
{
    // calculate distance between newLocation and lastLocation
    CLLocationDistance deltaDistance = [newLocation distanceFromLocation:self.lastLocation];
    
    //            if we're moving quickly, we will save points less frequently.
    CLLocationDistance minDistance = fmax(MIN_DISTANCE_BETWEEN_POINTS, newLocation.speed * 4); // 30m distance OR 27km/h or higher
    if ((deltaDistance >= minDistance) || !self.lastLocation) {
        
        // make lastPromptedLocation to be used for Modeprompt
        if (!lastPromptedLocation) {
            lastPromptedLocation = newLocation;
        }
        
        // for modeprompt on app terminated
        if (isAppTerminated) {
            float tmp= [newLocation.timestamp timeIntervalSinceDate:self.lastInsertedLocation.timestamp];
            int hh = (int)(tmp / 3600);
            int mm = (int)((tmp-hh) / 60);
            if (mm>=DM_MODEPROMPT_THRESHOLD_ON_APP_TERMINATED) {
                // if no new location for more than 2min, make modeprompt
                lastPromptedLocation = self.lastInsertedLocation;
                isModeprompting = YES;
                
                // draw region overlay
                // for DMPointOptions
                self.isMonitoringForRegionExit = YES;
                //            mark previous location as involving a region change
                [self addOptionsToLastInsertedPoint:DMPointMonitorRegionStartPoint];
            } else {
                if (!isModeprompting) {  // if isModeprompting, the notification stays
                    // cancel the notification for modeprompt on AppTerminated, if this isn't called for more than 2min, the notificatin will appear
                    if (!isDebugLogEnabled) {
                        [[UIApplication sharedApplication] cancelAllLocalNotifications];
                    }
                }
            }
        }
        
        DMPointOptions options = self.lastLocation ? 0 : DMPointLaunchPoint;
        if (self.isMonitoringForRegionExit) {
            options = (options | DMPointMonitorRegionExitPoint);
            self.isMonitoringForRegionExit = NO;
        }
        
        // save new location - EntityManager
        // and, update viewContents - DMMainView
        [self insertLocation:newLocation pointOptions:options];
        self.lastLocation = newLocation;
        
        
        // for DMDebugLogView
        if (isDebugLogEnabled) {
            // show  accuracy / recorded
            [debugLogView showRecorded:newLocation];
            // set localNotification
            [debugLogView notifyDebugLog:@"Recorded " region:nil location:(CLLocation *)newLocation];
        }
    }
    
    [self resetBBadLocation];
}


#pragma mark - onAppTerminated

// for ready to update location and create region on app terminated
- (void)readyOnAppTerminated
{
    // it must run timer to create region and quit processing, because bgTask will finish in 3 min
    if (!self.appTerminatedTimer) {
        self.appTerminatedTimer = [NSTimer scheduledTimerWithTimeInterval:APP_TERMINATED_TIMER target:self selector:@selector(readyToCreateRegionOnAppTerminated:) userInfo:nil repeats:NO];
    }
    
    if (bgTask==UIBackgroundTaskInvalid) {
        UIApplication* app = [UIApplication sharedApplication];
        bgTask = [app beginBackgroundTaskWithExpirationHandler:^{

            [app endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
        }];
    }
}

- (void)readyToCreateRegionOnAppTerminated:(NSTimer *)appTerminatedTimer
{
    if (isAppTerminated) {
        [self createRegionOnAppTerminated];
    }
    
    // quit timer
    [self.appTerminatedTimer invalidate];
    self.appTerminatedTimer = nil;
    
    // quit bgTask
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
}

- (void)createRegionOnAppTerminated
{
    // record bestBadLocation, if lastLocation doesn't exist when DM is terminating
    if (!self.lastLocation) {
        if (self.bestBadLocation.horizontalAccuracy<=BBAD_MIN_HORIZONTAL_ACCURACY && self.bestBadLocation) {
            // if bestBadLocation is same as lastInsertedLocation, don't record it
            CLLocationDistance deltaDistance = [self.bestBadLocation distanceFromLocation:self.lastInsertedLocation];
            if (deltaDistance>=MIN_DISTANCE_BETWEEN_POINTS || !self.lastInsertedLocation) {
                [self recordLocation:self.bestBadLocation];
            }
        }
    }
    
    // start significant location
//    if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
//        [self.locationManager startMonitoringSignificantLocationChanges];
//    }
    
    // if region doesn't exit, create
    if (!self.movingRegion) {
        
        // adjust location for region depending on accuracy
        CLLocation* newLocation;
        newLocation = self.updatedNewLocation;
        if (self.updatedNewLocation && self.updatedNewLocation.horizontalAccuracy>BBAD_MIN_HORIZONTAL_ACCURACY) {
            if (self.bestBadLocation.horizontalAccuracy<=BBAD_MIN_HORIZONTAL_ACCURACY && self.bestBadLocation) {
                newLocation = self.bestBadLocation;
            }else if (self.lastLocation) {
                newLocation = self.lastLocation;
            }else{
                newLocation = self.lastInsertedLocation;
            }
        }
        else if (!self.updatedNewLocation || (self.updatedNewLocation.coordinate.latitude==0.0&&self.updatedNewLocation.coordinate.latitude==0.0)) {
            if (self.bestBadLocation.horizontalAccuracy<=BBAD_MIN_HORIZONTAL_ACCURACY && self.bestBadLocation) {
                newLocation = self.bestBadLocation;
            }else if (self.lastLocation) {
                newLocation = self.lastLocation;
            }else{
                newLocation = self.lastInsertedLocation;
            }
        }
        
        // create region
        if (newLocation.horizontalAccuracy<=MIN_HORIZONTAL_ACCURACY) {
            // if accuracy is good, create small geofence size
            // adjust region radius
            CLLocationDistance radius = [self adjustRegionRadiusOnAppTerminated:newLocation];
            // create a region to monitor
            self.movingRegion = [DMEfficientLocationManager regionWithCenter:newLocation.coordinate
                                                                      radius:radius
                                                                  identifier:@"movingRegionOnAppTerminated"];
        }
        else{
            // if accuracy is not good, create normal geofence size
            // adjust region radius
            CLLocationDistance radius = [self adjustRegionRadius:newLocation];
            // create a region to monitor
            self.movingRegion = [DMEfficientLocationManager regionWithCenter:newLocation.coordinate
                                                                      radius:radius
                                                                  identifier:@"movingRegionOnAppTerminated"];
        }
        
        // if region is created
        if (self.movingRegion) {
            // start monitoring region
            [self.locationManager startMonitoringForRegion:self.movingRegion];
            [self switchToWifiForRegion:self.movingRegion];
            
            // for DMDebugLogView
            if (isDebugLogEnabled) {
                // update viewContents - DMMainView - set RegionOverlay
                [self.displayDelegate locationDataSource:self
                      didStartMonitoringRegionOnAppTerminatedWithCenter:self.movingRegion.center
                                                  radius:self.movingRegion.radius];
                // set localNotification
                [debugLogView notifyDebugLog:@"createRegionOnAppTerminated " region:nil location:(CLLocation *)newLocation];
            }
        }else{
            // start significant location
//            if ([CLLocationManager significantLocationChangeMonitoringAvailable]) {
//                [self.locationManager startMonitoringSignificantLocationChanges];
//            }
            // for DMDebugLogView
            if (isDebugLogEnabled) {
                // set localNotification
                [debugLogView notifyDebugLog:@"NoRegionOnAppTerminated " region:nil location:(CLLocation *)newLocation];
            }
        }
    }
    // if region has already existed with normal geofence
    else{
        // for DMDebugLogView
        if (isDebugLogEnabled) {
            // set localNotification
            [debugLogView notifyDebugLog:@"AppTerminatedWithNormalGeofence " region:nil location:self.lastLocation];
        }
    }
}

- (CLLocationDistance)adjustRegionRadius:(CLLocation*)location
{
    CLLocationDistance radius = location.horizontalAccuracy*1.1;
    if (radius<=DM_MONITORED_REGION_RADIUS_BBAD_MIN) {
        radius = DM_MONITORED_REGION_RADIUS_BBAD_MIN;
    }else if (radius>=DM_MONITORED_REGION_RADIUS_BBAD_MAX) {
        radius = DM_MONITORED_REGION_RADIUS_BBAD_MAX;
    }
    return radius;
}

- (CLLocationDistance)adjustRegionRadiusOnAppTerminated:(CLLocation*)location
{
    CLLocationDistance radius = location.horizontalAccuracy*0.1;
    if (radius<=DM_MONITORED_REGION_RADIUS_ON_APP_TERMINATED_MIN) {
        radius = DM_MONITORED_REGION_RADIUS_ON_APP_TERMINATED_MIN;
    }else if (radius>=DM_MONITORED_REGION_RADIUS_ON_APP_TERMINATED_MAX) {
        radius = DM_MONITORED_REGION_RADIUS_ON_APP_TERMINATED_MAX;
    }
    return radius;
}


- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    if ([error domain] == kCLErrorDomain && [error code] == 0)
    {
        [manager startUpdatingLocation];
    }
    DDLogWarn(@"location manager failed: %@", error.localizedDescription);
}


@end
