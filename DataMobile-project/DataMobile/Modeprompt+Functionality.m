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
//  Modeprompt+Functionality.m
//  DataMobile
//
//  Created by Takeshi MUKAI on 11/13/15.
//  Copyright (c) 2015 MML-Concordia. All rights reserved.
//

#import "Modeprompt+Functionality.h"

@implementation Modeprompt (Functionality)


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
        
        return [NSString stringWithFormat:@"%f, %f, %@, %@, %@\n",
                self.latitude,
                self.longitude,
                [ISO8601Formatter stringFromDate:[self dateFromTimeStamp]],
                self.mode,
                self.purpose];
    }
    else
    {
        return [NSString stringWithFormat:@"%f, %f, %f, %@, %@\n",
                self.latitude,
                self.longitude,
                self.timestamp,
                self.mode,
                self.purpose];
    }
}

- (NSDate *)dateFromTimeStamp
{
    return [NSDate dateWithTimeIntervalSinceReferenceDate:self.timestamp];
}

@end