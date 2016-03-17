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
//  LocationMapViewController.m
//  BasicExample
//
//  Created by Nick Lockwood on 24/03/2014.
//  Copyright (c) 2014 Charcoal Design. All rights reserved.
//
// Modified by MUKAI Takeshi in 2015-10

#import "LocationMapViewController.h"
#import <MapKit/MapKit.h>


@interface LocationMapViewController () <MKMapViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, strong) IBOutlet MKMapView *mapView;
@property (strong, nonatomic) MKPointAnnotation* userLocation;
@property (strong, nonatomic) CLGeocoder* geocoder;
@property (strong, nonatomic) MKPinAnnotationView* pin;
@end


@implementation LocationMapViewController
@synthesize usDataManager;
@synthesize delegate;

//- (void)viewWillAppear:(BOOL)animated
//{
//    [super viewWillAppear:animated];
//}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    // get instance from usDataManager
    usDataManager = [DMUSDataManager instance];
    
    if (usDataManager.memberType==0||usDataManager.memberType==1||(usDataManager.memberType==3&&!usDataManager.isWorkInfoEnded)) {
        // work
        mType = 1;
    }else if (usDataManager.memberType==2||(usDataManager.memberType==3&&usDataManager.isWorkInfoEnded)) {
        // study
        mType = 2;
    }else{
        // home
        mType = 0;
    }
    
    // get location - start locationManager
    if(!locationManager){
        locationManager = [[CLLocationManager alloc] init];
        locationManager.delegate = self;
        locationManager.distanceFilter = kCLDistanceFilterNone;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    
    // for iOS8 above
    if( [[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0 ) {
        //        [locationManager requestWhenInUseAuthorization];
        [locationManager requestAlwaysAuthorization];
    }
    if([CLLocationManager locationServicesEnabled]){
        [locationManager startUpdatingLocation];
    }else{
        // if locationServices is disabled
        [self startMapViewWithoutLocationServices];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// updateLocation
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(newLocation.coordinate.latitude, newLocation.coordinate.longitude);
    [self startMapView:coordinate];
    // stopUpdating just for one time
    [locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if (error) {
        switch ([error code]) {
            case kCLErrorDenied:
                NSLog(@"%@", @"locationServices is disabled");
                break;
            default:
                NSLog(@"%@", @"failed to get location");
                break;
        }
    }
    [self startMapViewWithoutLocationServices];
    [locationManager stopUpdatingLocation];
}

- (void)startMapViewWithoutLocationServices
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(45.4937774, -73.5774114);
    [self startMapView:coordinate];
}

- (void)startMapView:(CLLocationCoordinate2D)coordinate
{
    if (!isMapViewStarted) {
        NSString *title = @"Drag me to a location!";
        NSString *subtitle = nil;
        
        // set data from the last time
        if ((mType==1&&usDataManager.locationWork.count)||(mType==2&&usDataManager.locationStudy.count)||(mType==0&&usDataManager.locationHome.count)) {
            CLLocation *location;
            if (mType==1) {
                title = usDataManager.locationWork[@"placename"];
                location = (CLLocation*)usDataManager.locationWork[@"location"];
            }else if (mType==2) {
                title = usDataManager.locationStudy[@"placename"];
                location = (CLLocation*)usDataManager.locationStudy[@"location"];
            }else if (mType==0) {
                title = usDataManager.locationHome[@"placename"];
                location = (CLLocation*)usDataManager.locationHome[@"location"];
            }
            subtitle = @"Drag to change location";
            coordinate = location.coordinate;
        }
        
        self.userLocation = [[MKPointAnnotation alloc]init];
        self.userLocation.coordinate = coordinate;
        self.userLocation.title = title;
        self.userLocation.subtitle = subtitle;
        [self.mapView addAnnotation:self.userLocation];
        [self.mapView selectAnnotation:self.userLocation animated:YES];
        
        MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(coordinate, 5000, 5000);
        MKCoordinateRegion adjustedRegion = [self.mapView regionThatFits:viewRegion];
        [self.mapView setRegion:adjustedRegion animated:YES];
        
        isMapViewStarted = YES;
    }
}

// this is all stuff for disabling the swipe-from-edge gesture that was causing a weird display bug
// see http://stackoverflow.com/a/23271841/1529922
- (void)viewDidAppear:(BOOL)animated {
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
        self.navigationController.interactivePopGestureRecognizer.delegate = self;
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // Enable iOS 7 back gesture
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        self.navigationController.interactivePopGestureRecognizer.delegate = nil;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return NO;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    self.pin = [[MKPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:nil];
    self.pin.draggable = YES;
    self.pin.canShowCallout = YES;
    self.pin.pinColor = 2;
    self.pin.animatesDrop = YES;
    return self.pin;
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapView {
    // set annotaion, but this is called when map is loaded first time(next time even in new viewDidLoad, will not call this, because of cache).
//    [mapView selectAnnotation:self.userLocation animated:YES];
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view didChangeDragState:(MKAnnotationViewDragState)newState fromOldState:(MKAnnotationViewDragState)oldState {
    if (newState == MKAnnotationViewDragStateEnding) {
        CLLocation* location = [[CLLocation alloc] initWithLatitude:view.annotation.coordinate.latitude
                                                          longitude:view.annotation.coordinate.longitude];
        
        // set data
        if (mType==1) {
            usDataManager.locationWork = @{@"location": location};
        }else if (mType==2) {
            usDataManager.locationStudy = @{@"location": location};
        }else if (mType==0) {
            usDataManager.locationHome = @{@"location": location};
        }

        [self.geocoder cancelGeocode];
        self.geocoder = [[CLGeocoder alloc]init];
        [self.geocoder reverseGeocodeLocation:location
                            completionHandler:^(NSArray *placemarks, NSError *error) {
                                CLPlacemark *placemark = (CLPlacemark*)placemarks.firstObject;
                                NSString *placename = placemark.subLocality;
                                if (!placename) {
                                    placename = placemark.locality;
                                }
                                if (!placename) {
                                    placename = placemark.inlandWater;
                                }
                                if (placename) {
                                    self.title = placename;
                                    
                                    // set data
                                    if (mType==1) {
                                        usDataManager.locationWork = @{@"location": location, @"placename": placename};
                                    }else if (mType==2) {
                                        usDataManager.locationStudy = @{@"location": location, @"placename": placename};
                                    }else if (mType==0) {
                                        usDataManager.locationHome = @{@"location": location, @"placename": placename};
                                    }
                                    self.userLocation.title = placename;
                                    self.userLocation.subtitle = @"Drag to change location";
                                }
                            }];
        // delegate to
        [delegate locationEntered];
    }
}

@end
