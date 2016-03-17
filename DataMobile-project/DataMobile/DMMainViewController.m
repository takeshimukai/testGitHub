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
//  DMMainViewController.m
//  DataMobile
//
//  Created by Colin Rofls on 2014-07-14.
//  Copyright (c) 2014 MML-Concordia. All rights reserved.
//
// Modified by MUKAI Takeshi in 2015-10

#import "DMMainViewController.h"

//#import "NotificationDispatcher.h"
#import "CoreDataHelper.h"
#import "EntityManager.h"
#import "DMUserSurveyForm.h"

#import "DMLocationManager.h"
#import "DMPathOverlay.h"
#import "DMPathOverlayRenderer.h"

#import "UIView+AutoLayout.h"

#import <MapKit/MapKit.h>
#import <MessageUI/MessageUI.h>

#import "DMAppDelegate.h"


@interface DMMainViewController () <MKMapViewDelegate, MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) UIButton* locationButton;
@property (strong, nonatomic) UIButton* infoButton;

@property (weak, nonatomic) IBOutlet UILabel *surveyCompleteLabel;
@property (strong, nonatomic) NSDate* surveyStartDate;
@property (strong, nonatomic) NSDate* displayStartDate;
@property (strong, nonatomic) NSDate* displayEndDate;

@property (strong, nonatomic) DMLocationManager *locationManager;
@property (strong, nonatomic) CLLocation* lastLocation;
@property (strong, nonatomic) DMPathOverlay* overlay;
@property (strong, nonatomic) DMPathOverlayRenderer* overlayRenderer;
@property (strong, nonatomic) MKCircle* monitoredRegionOverlay;
@property (strong, nonatomic) MKCircleRenderer* monitoredRegionOverlayRenderer;

@property (nonatomic) BOOL needsToCenterOnUserLocation;
@property (nonatomic) BOOL shouldAddNewPoints;

// Modified by MUKAI Takeshi in 2015-10
@property (nonatomic) NSInteger totalPoints;
@property (nonatomic) NSInteger totalDays;
@property (strong, nonatomic) IBOutlet UILabel* totalPointsLabel;
@property (strong, nonatomic) IBOutlet UILabel* totalDaysLabel;
@property (strong, nonatomic) IBOutlet UIButton* dateButton;
@property (strong, nonatomic) MKCircle* monitoredRegionOverlayOnAppTerminated;
@property (strong, nonatomic) MKCircleRenderer* monitoredRegionOverlayRendererOnAppTerminated;

@end

@implementation DMMainViewController
{
    DMDatePickerValue _datePickerValue;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (DMLocationManager*)locationManager {
    if (!_locationManager) {
        _locationManager = [DMLocationManager defaultLocationManager];
        _locationManager.displayDelegate = self;
    }
    return _locationManager;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // set default start dates:
    _datePickerValue = DMDatePickerValueToday;
    self.displayStartDate = [self todayStartDate];
    self.displayEndDate = [NSDate dateWithTimeInterval:(24*60*60) sinceDate:self.displayStartDate];
    
    // mapView
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;

    // set dropshadow: topContainrView
    self.topContainerView.layer.masksToBounds = NO;
    self.topContainerView.layer.shadowRadius = 5.0;
    self.topContainerView.layer.shadowOpacity = 0.5;
    
    // set button
    [self setupLocationButton];
    [self setupInfoButton];

    
//    we use didEnterForeground to make sure our date-based views are up to date
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(didEnterForeground)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    
//    check to make sure that the survey is ongoing:
    self.surveyStartDate = [[NSUserDefaults standardUserDefaults]objectForKey:DM_SURVEY_START_DATE_KEY];
    NSAssert([self.surveyStartDate isKindOfClass:[NSDate class]], @"surveyStartDate is required, must be a date");
    
    NSTimeInterval surveyDurationSeconds = DM_DAY_DURATION_OF_SURVEY * SECONDS_IN_A_DAY;
    
    if ([[NSDate date]timeIntervalSinceDate:self.surveyStartDate] > surveyDurationSeconds) {
//        the survey is complete. We do not want to start updating the location.
        //    TODO: unstub me
        self.mapView.showsUserLocation = NO;
        self.surveyCompleteLabel.hidden = NO;
        self.locationButton.enabled = NO;
    }else{
        // if the survey is not competed, ready to start
        // check if we can use notifications, and do so
//        [self checkAuthorizationStatus];
        
        // set notfication for alert when the app is not running
//        [NotificationDispatcher startNotificationDispatcher];
        
        // startDMLocationManager in DMEfficientLocationManager
        [self.locationManager startDMLocatinoManager];
        
        // refresh
        [self refreshViews];
        [self centerOnUserLocation];
    }
}

- (void)checkAuthorizationStatus {
    // location
    CLAuthorizationStatus status = [self.locationManager authorizationStatus];
    NSString *prompt;
    if (status == kCLAuthorizationStatusDenied) {
        prompt = NSLocalizedString(@"For DataMobile to function, please allow it to access your location in settings.", nil);
    }
    if (prompt) {
        NSString *title = @"Access to Location Not Authorized";
        
        // if iOS8 or above
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            // Open Setting
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:prompt preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                // URL Scheme to Setting
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                [[UIApplication sharedApplication] openURL:url];
            }]];
            [self presentViewController:alertController animated:YES completion:nil];
            
        }else {
            UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:NSLocalizedString(title, nil)
                                                               message:prompt
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                     otherButtonTitles:nil];
            [alertView show];
        }
    }
    
    // background app refresh
    if([[UIApplication sharedApplication] backgroundRefreshStatus] != UIBackgroundRefreshStatusAvailable)
    {
        NSString *prompt = NSLocalizedString(@"For DataMobile to function, please allow Background App Refresh in settings.", nil);
        NSString *title = @"Background App Refresh";
        // if iOS8 or above
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
            // Open Setting
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:prompt preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            }]];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                // URL Scheme to Setting
                NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
                [[UIApplication sharedApplication] openURL:url];
            }]];
            [self presentViewController:alertController animated:YES completion:nil];
            
        }else {
            UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:NSLocalizedString(title, nil)
                                                               message:prompt
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                     otherButtonTitles:nil];
            [alertView show];
        }
    }
}

- (void)setupLocationButton
{
    self.locationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.view addSubview:self.locationButton];
    
    UIImage *locationImage = [[UIImage imageNamed:@"crosshair2"]imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.locationButton setImage:locationImage forState:UIControlStateNormal];
    self.locationButton.layer.cornerRadius = 3.0f;
    self.locationButton.layer.borderColor = [[UIColor lightGrayColor]CGColor];
    self.locationButton.layer.borderWidth = 0.5f;
    self.locationButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.7];
//    self.locationButton.backgroundColor = [UIColor whiteColor];
    self.locationButton.layer.masksToBounds = NO;

    self.locationButton.layer.shadowRadius = 1.0;
    self.locationButton.layer.shadowOffset = CGSizeZero;
    self.locationButton.layer.shadowOpacity = 0.3;

    self.locationButton.tintColor = [UIColor blackColor];
    
    [self.locationButton addTarget:self action:@selector(centerOnUserLocation) forControlEvents:UIControlEventTouchUpInside];
    [self.locationButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.topContainerView withOffset:8.0];
    [self.locationButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:8.0];
}

- (void)setupInfoButton
{
    self.infoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.infoButton setTitle:NSLocalizedString(@"About DataMobile", nil) forState:UIControlStateNormal];
    self.infoButton.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    [self.view addSubview:self.infoButton];
    
    [self.infoButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:2.0];
    [self.infoButton autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:8.0];
    
//    maybe put a shadow under there, also?
//    self.infoButton.layer.shadowColor = [[UIColor whiteColor]CGColor];
    self.infoButton.layer.masksToBounds = NO;
    self.infoButton.layer.shadowRadius = 1.0;
    self.infoButton.layer.shadowColor = [[UIColor whiteColor]CGColor];
    self.infoButton.layer.shadowOpacity = 1.0;
    self.infoButton.layer.shadowOffset = CGSizeZero;
  
    [self.infoButton addTarget:self action:@selector(infoButtonAction:) forControlEvents:UIControlEventTouchUpInside];
}


#pragma mark - UI logic

// refresh - UI, location overlays
- (void)refreshViews {
    
    if ([self.displayEndDate timeIntervalSinceNow] < 0) {
        //                if our end date is in the past we don't want to draw new points
        self.shouldAddNewPoints = NO;
    }else{
        self.shouldAddNewPoints = YES;
    }

    // get all locations on seleced dates
    NSArray* locations = [[CoreDataHelper instance].entityManager
                          fetchLocationsFromDate:self.displayStartDate
                          ToDate:self.displayEndDate];
    
    // remove overlays (init)
    self.overlayRenderer = nil;
    if (self.overlay) {
        [self.mapView removeOverlay:self.overlay];
    }
    NSUInteger points = 0;
    CLLocationDistance distance = 0;
//    NSTimeInterval time = 0.0;  // it can be used as totalTime of the app's running time

    
    // set overlays on selected dates, and get totalPoints info
    if (locations.count) {
        self.overlay = [[DMPathOverlay alloc]initWithLocations:locations];

        CLLocation *previousLocation;
        CLLocation *location;
        NSTimeInterval previousLocationTimestamp = 0.0f;
        
        for (Location *locationRep in locations) {
            points++;
            location = [[CLLocation alloc]initWithLatitude:locationRep.latitude longitude:locationRep.longitude];
            
            if (previousLocation) {
                distance += [previousLocation distanceFromLocation:location];
            }
//            if (!(locationRep.pointType & DMPointLaunchPoint) && previousLocationTimestamp) {
//                time += locationRep.timestamp - previousLocationTimestamp;
//            }
            
            previousLocationTimestamp = locationRep.timestamp;
            previousLocation = location;
        }
        
        [self.mapView addOverlay:self.overlay];
        self.lastLocation = location;
        
//        set map rect to encompass all visible points:
        MKMapRect overlayMapRect = [self.overlay computedMapRect];
        [self.mapView setVisibleMapRect:overlayMapRect edgePadding:UIEdgeInsetsMake(5, 5, 5, 5) animated:YES];
    }else{
        // if no locations, center (and zoom) the current user location on Map
        self.needsToCenterOnUserLocation = YES;
    }
    
    
    // Modified by MUKAI Takeshi in 2015-10
    // set textLabel on topContainer
    // Point Recoded
    self.totalPoints = points;
    self.totalPointsLabel.text = [NSString localizedStringWithFormat:@"%ld", (long)self.totalPoints];
    
    // Days Remaining of survey
    NSTimeInterval timeIntervalSinceSurveyStart = [[NSDate date]timeIntervalSinceDate:self.surveyStartDate];
    NSInteger dayOfSurvey = timeIntervalSinceSurveyStart / SECONDS_IN_A_DAY;
    self.totalDays = MAX(DM_DAY_DURATION_OF_SURVEY - dayOfSurvey, 0);
    self.totalDaysLabel.text = [NSString localizedStringWithFormat:@"%ld", (long)self.totalDays];
}

- (MKOverlayRenderer*)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {

    if (overlay == self.overlay) {
        if (!_overlayRenderer) {
            _overlayRenderer = [[DMPathOverlayRenderer alloc]initWithOverlay:overlay];
        }
        return _overlayRenderer;
    }else if (overlay == self.monitoredRegionOverlay) {
        if (!_monitoredRegionOverlayRenderer) {
            _monitoredRegionOverlayRenderer = [[MKCircleRenderer alloc]initWithCircle:overlay];
            // set color for region overlay, size depends on region radius
            _monitoredRegionOverlayRenderer.fillColor = [UIColor colorWithRed:88.0/255.0 green:82.0/255.0 blue:229.0/255.0 alpha:0.2];
        }
        return _monitoredRegionOverlayRenderer;
    }
    // region onAppTerminated
    else if (overlay == self.monitoredRegionOverlayOnAppTerminated) {
        if (!_monitoredRegionOverlayRendererOnAppTerminated) {
            _monitoredRegionOverlayRendererOnAppTerminated = [[MKCircleRenderer alloc]initWithCircle:overlay];
            // set color for region overlay, size depends on region radius
            _monitoredRegionOverlayRendererOnAppTerminated.fillColor = [UIColor colorWithRed:252.0/255.0 green:83.0/255.0 blue:109.0/255.0 alpha:0.4];
        }
        return _monitoredRegionOverlayRendererOnAppTerminated;
    }
    return nil;
}


#pragma mark - user interactions

#define DMInfoSegueIdentifier @"infoSegue"
#define DMDatePickerSegueIdentifer @"datePickerSegue"

- (void)centerOnUserLocation {

    if (self.mapView.showsUserLocation) {
        
        CLLocationCoordinate2D userLocationCoordinate = self.mapView.userLocation.coordinate;
    //    if coordinate is (0,0) wait to center
        if (!userLocationCoordinate.latitude && !userLocationCoordinate.longitude) {
            self.needsToCenterOnUserLocation = YES;
        }else{
            [self centerOnCoordinate:userLocationCoordinate];
        }
        
    }else{
//        if no user location is visible it's probably because we've switched to region tracking, so:
        MKMapRect monitoredArea = self.monitoredRegionOverlay.boundingMapRect;
        [self.mapView setVisibleMapRect:monitoredArea edgePadding:UIEdgeInsetsMake(30, 30, 30, 30) animated:YES];
    }
}

- (void)centerOnCoordinate:(CLLocationCoordinate2D)coordinate {
    MKCoordinateRegion region = { coordinate, { 0.0078, 0.0068 } };
    [self.mapView setRegion:region animated:YES];
}

- (void)infoButtonAction:(id)sender {
    [self performSegueWithIdentifier:DMInfoSegueIdentifier sender:sender];
}

- (IBAction)datePickerAction:(id)sender {
    [self performSegueWithIdentifier:DMDatePickerSegueIdentifer sender:sender];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:DMDatePickerSegueIdentifer])
    {
        DMDatePickerViewController *vc = (DMDatePickerViewController*)[segue destinationViewController];
        vc.delegate = self;
    }
}


#pragma mark - display delegate

// delegate from DMLocationManager - when new location is inserted - update viewContents
- (void)locationDataSource:(id)dataSource didAddLocation:(CLLocation *)location pointOptions:(DMPointOptions)pointOptions {
    
    // center (and zoom) the added location on Map
    if (self.needsToCenterOnUserLocation) {
        self.needsToCenterOnUserLocation = NO;
        [self centerOnCoordinate:location.coordinate];
    }
    
    if (self.shouldAddNewPoints) {
        // set overlays
        if (!self.overlay) {
            self.overlay = [[DMPathOverlay alloc]initWithCoordinate:location.coordinate];
            [self.mapView addOverlay:self.overlay];
        }else{
            [self.overlay addLocation:location.coordinate pointOptions:pointOptions];
        }
        
    //    we only update the rect that has changes; this is from the breadcrumbs sample project
        MKMapRect updateRect = [self.overlay mapRectToUpdate];
        if (!MKMapRectIsNull(updateRect))
        {
            // There is a non null update rect.
            // Compute the currently visible map zoom scale
            MKZoomScale currentZoomScale = (CGFloat)(self.mapView.bounds.size.width / self.mapView.visibleMapRect.size.width);
            // Find out the line width at this zoom scale and outset the updateRect by that amount
            CGFloat lineWidth = MKRoadWidthAtZoomScale(currentZoomScale);
            updateRect = MKMapRectInset(updateRect, -lineWidth, -lineWidth);
            // Ask the overlay view to update just the changed area.
            [self.overlayRenderer setNeedsDisplayInMapRect:updateRect];
        }
        
        // set textLabel on topContainer
        self.totalPoints += 1;
        self.totalPointsLabel.text = [NSString localizedStringWithFormat:@"%ld", (long)self.totalPoints];
        self.lastLocation = location;
    }
}

// delegate from DMLocationManager - when it is switched(created) to region geofence - update viewContents
- (void)locationDataSource:(id)dataSource didStartMonitoringRegionWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius {
    if (self.monitoredRegionOverlay) {
        [self.mapView removeOverlay:self.monitoredRegionOverlay];
        self.monitoredRegionOverlay = nil;
        self.monitoredRegionOverlayRenderer = nil;
    }
    // set new regionOverlay
    self.monitoredRegionOverlay = [MKCircle circleWithCenterCoordinate:center
                                                                radius:radius];
    [self.mapView addOverlay:self.monitoredRegionOverlay];
    self.mapView.showsUserLocation = NO;
}

// delegate from DMLocationManager - when it is switched to gps(region is removed) - update viewContents
- (void)locationDataSourceStoppedMonitoringRegion {
    [self.mapView removeOverlay:self.monitoredRegionOverlay];
    self.monitoredRegionOverlay = nil;
    self.monitoredRegionOverlayRenderer = nil;
    self.mapView.showsUserLocation = YES;
}

// delegate from DMEfficientLocationManager - regionOnAppTerminated
- (void)locationDataSource:(id)dataSource didStartMonitoringRegionOnAppTerminatedWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius {
    if (self.monitoredRegionOverlayOnAppTerminated) {
        [self.mapView removeOverlay:self.monitoredRegionOverlayOnAppTerminated];
        self.monitoredRegionOverlayOnAppTerminated = nil;
        self.monitoredRegionOverlayRendererOnAppTerminated = nil;
    }
    // set new regionOverlay
    self.monitoredRegionOverlayOnAppTerminated = [MKCircle circleWithCenterCoordinate:center
                                                                radius:radius];
    [self.mapView addOverlay:self.monitoredRegionOverlayOnAppTerminated];
}

// delegate from DMDebugLog - regionOnAppTerminated
- (void)locationDataSourceStoppedMonitoringRegionOnAppTerminated {
    [self.mapView removeOverlay:self.monitoredRegionOverlayOnAppTerminated];
    self.monitoredRegionOverlayOnAppTerminated = nil;
    self.monitoredRegionOverlayRendererOnAppTerminated = nil;
}


#pragma mark - picker delegate

- (void)dateRangeDidChangeToStart:(NSDate *)startDate Stop:(NSDate *)stopDate {
    //    TODO: unstub me
    NSLog(@"stub");
}

- (DMDatePickerValue)datePickerValue {
    return _datePickerValue;
}

- (NSDate*)startDate {
    return [self.displayStartDate copy];
}

- (NSDate*)endDate {
    return [self.displayEndDate copy];
}

- (void)datePicker:(DMDatePickerViewController *)datePicker didPickValue:(DMDatePickerValue)datePickerValue {
    if (datePickerValue != _datePickerValue || datePickerValue == DMDatePickerValueCustom) {
        _datePickerValue = datePickerValue;
        
        self.displayStartDate = [datePicker.startDate copy];
        self.displayEndDate = [datePicker.endDate copy];
        
        NSString *buttonLabelText;
        switch (datePickerValue) {
            case DMDatePickerValueToday:
                buttonLabelText = NSLocalizedString(@"Today", nil);
                break;
            case DMDatePickerValueYesterday:
                buttonLabelText = NSLocalizedString(@"Yesterday", nil);
                break;
            case DMDatePickerValueLastSevenDays:
                buttonLabelText = NSLocalizedString(@"Last Seven Days", nil);
                break;
            case DMDatePickerValueAll:
                buttonLabelText = NSLocalizedString(@"All Days", nil);
                break;
            case DMDatePickerValueCustom:
                buttonLabelText = [self displayStringForDateRange:self.displayStartDate End:self.displayEndDate];
                break;
            default:
                abort(); // crash if we add a new case and forget to implement this
                break;
        }
        
        [self.dateButton setTitle:buttonLabelText forState:UIControlStateNormal];
        [self refreshViews];
    }
}


#pragma mark - notifications

- (void)didEnterForeground {
    // check if we can use notifications, and do so
    [self checkAuthorizationStatus];
    
//    check to see if our display values are still valid:
    DDLogInfo(@"didEnterForeground called");
    if (self.datePickerValue == DMDatePickerValueToday) {
        if (![self.displayStartDate isEqualToDate:[self todayStartDate]]) {
            self.displayStartDate = [self todayStartDate];
            self.displayEndDate = [self.displayStartDate dateByAddingTimeInterval:SECONDS_IN_A_DAY];
            [self refreshViews];
        }
    }
    
    // refresh view to show paths correctly when app is relaunched
    if (!self.surveyCompleteLabel.hidden) {
        [self refreshViews];
        [self centerOnUserLocation];
    }
}


#pragma mark - helpers

- (NSString*)displayStringForDateRange:(NSDate*)start End:(NSDate*)end {
    static NSDateFormatter *formatter;
    if (!formatter) {
        formatter = [[NSDateFormatter alloc]init];
        [formatter setDateFormat:@"MMM d"];
    }
    
    NSString *startString = [formatter stringFromDate:start];
    NSString *endString = [formatter stringFromDate:end];
    return [NSString stringWithFormat:@"%@ - %@", startString, endString];
}

//today currently starts at 12am. This could be a user setting?
- (NSDate*)todayStartDate
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitDay | NSCalendarUnitMonth)
                                               fromDate:[NSDate date]];
    components.hour = 0;
    components.minute = 0;
    components.second = 0;
    
    return [calendar dateFromComponents:components];
}

- (NSDate*)_debugStartDate {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitDay | NSCalendarUnitMonth)
                                               fromDate:[NSDate date]];
    components.month = 6;
    components.day = 1;
    components.hour = 4;
    components.minute = 0;
    components.second = 0;
    
    return [calendar dateFromComponents:components];
}


#pragma mark - debug

- (IBAction)debugSendLogsAction:(UIButton *)sender {
    
    MFMailComposeViewController *mailComposer = [[MFMailComposeViewController alloc] init];
    [mailComposer setSubject:@"DataMobile Log Data"];
    [mailComposer setToRecipients:@[@"colin.rothfels@gmail.com"]];
    
    NSString* logDirectoryPath = [self logDirectoryPath];
    NSArray *logFilePaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:logDirectoryPath error:nil];;
    [logFilePaths enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *filename = (NSString*)obj;
        NSString *path = [logDirectoryPath stringByAppendingPathComponent:filename];
        NSData *logData = [NSData dataWithContentsOfFile:path];
        [mailComposer addAttachmentData:logData mimeType:@"text/plain" fileName:filename];
        DDLogInfo(@"attached file %@, size: %@", filename, [NSByteCountFormatter stringFromByteCount:logData.length countStyle:NSByteCountFormatterCountStyleFile]);
    }];
    
    mailComposer.mailComposeDelegate = self;
    [self presentViewController:mailComposer animated:YES completion:NULL];
}

- (NSString*)logDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *baseDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *logsDirectory = [baseDir stringByAppendingPathComponent:@"Logs"];
    return logsDirectory;
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    DDLogInfo(@"mail composer finished with result: %u, error: %@", result, error.localizedDescription);
    [self dismissViewControllerAnimated:YES completion:NULL];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}

@end
