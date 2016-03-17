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
//  Location+Functionality.m
//
//
//  Created by Colin Rofls on 2014-07-22.
//
//
// Modified by MUKAI Takeshi in 2015-10

#import "Location+Functionality.h"

@implementation Location (Functionality)


- (CLLocation *)cllLocation
{
    return [[CLLocation alloc] initWithCoordinate:[self coordinate]
                                         altitude:self.altitude
                               horizontalAccuracy:self.h_accuracy
                                 verticalAccuracy:self.v_accuracy
                                           course:self.direction
                                            speed:self.speed
                                        timestamp:[self dateFromTimeStamp]];
}

- (CLLocationCoordinate2D)coordinate
{
    return CLLocationCoordinate2DMake(self.latitude,
                                      self.longitude);
}

- (CLLocationDistance)distanceWithLocation:(Location*)location
{
    CLLocation* selfLoc = [[CLLocation alloc] initWithLatitude:self.latitude
                                                     longitude:self.longitude];
    CLLocation* loc = [[CLLocation alloc] initWithLatitude:location.latitude
                                                 longitude:location.longitude];
    
    return [selfLoc distanceFromLocation:loc];
}

- (NSString*)csvStringWithFormattedTimeStamp:(BOOL)formatTimeStamp
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd hh:mm:ss"];
    
    if(formatTimeStamp)
    {
        NSDateFormatter *ISO8601Formatter = [[NSDateFormatter alloc]init];
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [ISO8601Formatter setLocale:enUSPOSIXLocale];
        [ISO8601Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
        
        // Modified by MUKAI Takeshi in 2015-10
        return [NSString stringWithFormat:@"%f, %f, %0.1f, %0.1f, %0.1f, %d, %@\n",
//                self.altitude,
                self.latitude,
                self.longitude,
                self.speed,
//                self.direction,
                self.h_accuracy,
                self.v_accuracy,
                self.pointType,
                [ISO8601Formatter stringFromDate:[self dateFromTimeStamp]]];
    }
    else
    {
        // Modified by MUKAI Takeshi in 2015-10        
        return [NSString stringWithFormat:@"%f, %f, %f, %f, %f, %f, %f, %d, %f\n",
                self.altitude,
                self.latitude,
                self.longitude,
                self.speed,
                self.direction,
                self.h_accuracy,
                self.v_accuracy,
                self.pointType,
                self.timestamp ];
    }
}

- (NSDate *)dateFromTimeStamp
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:self.timestamp];
}

@end
