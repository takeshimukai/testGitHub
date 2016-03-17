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
//  DataSender.m
//  DataMobile
//
//  Created by DataMobile on 13-07-26.
//  Copyright (c) 2013 MML-Concordia. All rights reserved.
//
// Modified by MUKAI Takeshi in 2015-10

#import "DataSender.h"
#import "User.h"
#import "CoreDataHelper.h"
#import "EntityManager.h"
#import "CSVExporter.h"
#import "UIDevice-Hardware.h"
#import "Config.h"
#import "DMGlobalLogger.h"
#import "DMUserSurveyForm.h"
#import "Modeprompt+Functionality.h"  // Modified by MUKAI Takeshi in 2015-11

@interface DataSender () <NSURLConnectionDelegate>

- (void)setObjectIfNotNil:(id)object
                  forKey:(id<NSCopying>)key
           inDictionnary:(NSMutableDictionary*)dictionnary;

@end

@implementation DataSender

static DataSender* instance;

/**
 * Singleton implementation
 */
+ (void)initialize
{
    if (instance == nil)
    {
        instance = [[DataSender alloc] init];
    }
}

+ (DataSender *)instance
{
    return instance;
}


// Modified by MUKAI Takeshi
- (NSDictionary*)postDataWithLocations:(NSArray*)locations modeprompts:(NSArray*)modeprompts {
    
    // ready data - user, location, modeprompts
    NSString* string_locations = [CSVExporter exportObjects:locations];
    NSString* string_modeprompts = [CSVExporter exportObjectsModeprompt:modeprompts];
    User* user = [[[CoreDataHelper instance] entityManager] fetchUser];
    
    // dataFormatter for the user created date
    NSDateFormatter *ISO8601Formatter = [[NSDateFormatter alloc]init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    [ISO8601Formatter setLocale:enUSPOSIXLocale];
    [ISO8601Formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    
    // set postData
    NSMutableDictionary* postData = [[NSMutableDictionary alloc] init];
    // locations
    postData[@"text"] = string_locations;
    // modeprompts
    postData[@"modeprompt"] = string_modeprompts;
    // user
    postData[@"id"] = user.device_id;
    postData[@"created_at"] = [ISO8601Formatter stringFromDate: user.created_at];
    postData[@"model"] = [[UIDevice currentDevice] modelName];
    postData[@"version"] = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    postData[@"os"] = @"iOS";
    postData[@"osversion"] = [[UIDevice currentDevice] systemVersion];
    postData[@"use_notifications"] = [[NSUserDefaults standardUserDefaults]boolForKey:DM_REMINDERS_FIELD_KEY] ? @"true" : @"false";
    
    postData[@"location_home"] = user.location_home;
    postData[@"location_work"] = user.location_work;
    postData[@"location_study"] = user.location_study;
    postData[@"travel_mode_work"] = user.travel_mode_work;
    postData[@"travel_mode_alt_work"] = user.travel_mode_alt_work;
    postData[@"travel_mode_study"] = user.travel_mode_study;
    postData[@"travel_mode_alt_study"] = user.travel_mode_alt_study;
    
    postData[@"member_type"] = user.member_type;
    postData[@"sex"] = user.sex;
    postData[@"age_bracket"] = user.age_bracket;
    postData[@"documents"] = user.user_docs;
    postData[@"people"] = user.lives_with;
    postData[@"num_of_people"] = user.num_of_people_living;
    postData[@"num_of_minors"] = user.num_of_minors;
    postData[@"num_of_cars"] = user.num_of_cars;
    postData[@"email"] = user.email;
    
    return postData;
}

// this is called when the app is DidBecomeActive
- (void)syncWithServer
{
    // Modified by MUKAI Takeshi in 2015-11
    // load data which has not been synched yet
    NSArray *locations = [[[CoreDataHelper instance] entityManager] fetchUnsyncedLocations];
    NSArray *modeprompts = [[[CoreDataHelper instance] entityManager] fetchUnsyncedModeprompts];
    
    // sync with server
    if (locations.count > 0 || modeprompts.count > 0) {
        NSDictionary *postData = [self postDataWithLocations:locations modeprompts:modeprompts]; // ready postData
        NSString* url = [[Config instance] stringValueForKey:@"insertLocationUrl"]; // ready URL from config.plist
        NSURLRequest *postRequest = [self requestWithPostData:postData ToURL:url]; // ready postRequest
        
        [NSURLConnection sendAsynchronousRequest:postRequest queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            DDLogInfo(@"received response to post request: %@", response);
            if (!connectionError) {  // if no error, set property - uploaded "YES"
                for (Location* location in locations) {
                    location.uploaded = YES;
                }
                for (Modeprompt* modeprompt in modeprompts) {
                    modeprompt.uploaded = YES;
                }
                [[[CoreDataHelper instance]entityManager]saveContext];
            }else{
                DDLogError(@"POST error: %@", connectionError);
            }
        }];
    }
}

// this is called by BackgroundFetch
- (void)syncWithServerSynchronously:(void(^)(BOOL success))completionBlock {
    DDLogInfo(@"attempting synchronus POST");
    
    // Modified by MUKAI Takeshi in 2015-11
    // load data which has not been synched yet
    NSArray *locations = [[[CoreDataHelper instance] entityManager] fetchUnsyncedLocations];
    NSArray *modeprompts = [[[CoreDataHelper instance] entityManager] fetchUnsyncedModeprompts];
    
    // sync with server
    if (locations.count > 0 || modeprompts.count > 0) {
        NSDictionary *postData = [self postDataWithLocations:locations modeprompts:modeprompts];
        NSString* url = [[Config instance] stringValueForKey:@"insertLocationUrl"];
        NSURLRequest *postRequest = [self requestWithPostData:postData ToURL:url];
        
        NSURLResponse *response;
        NSError *error = nil;
        [NSURLConnection sendSynchronousRequest:postRequest
                              returningResponse:&response
                                          error:&error];
        
        if (error == nil) {
            DDLogInfo(@"received response to synchronous POST: %@", response);
            for (Location* location in locations) {
                location.uploaded = YES;
            }
            for (Modeprompt* modeprompt in modeprompts) {
                modeprompt.uploaded = YES;
            }
            [[[CoreDataHelper instance]entityManager]saveContext];
            completionBlock(YES);
        }else{
            DDLogError(@"sync failed with error: %@, %@, %@", error.localizedDescription, error.localizedFailureReason, error.localizedRecoverySuggestion);
            completionBlock(NO);
        }
    } else { // there are no new locations; don't send
        completionBlock(YES);
    }
}

- (NSURLRequest*)requestWithPostData:(NSDictionary*)dico
                              ToURL:(NSString*)url
{
    NSMutableURLRequest* request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    request.HTTPMethod = @"POST" ;
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"content-type"];
    
    // adding Post Parameters to the request.
    NSString* requestString =[self addQueryStringToUrl:@"" params:dico];
    NSData* data = [NSData dataWithBytes:[requestString UTF8String] length:[requestString length]];
    request.HTTPBody = data;
    request.timeoutInterval = [[Config instance] integerValueForKey:@"connexionTimeoutSeconds"];
    
    return request;
}

+ (BOOL)errorMessageReceivedFromServer:(NSString*)dataResponse
{
    // matching the server response to "An error occured during saving your data"
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"An error occured during saving your data"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSArray *matches = [regex matchesInString:dataResponse
                                      options:0
                                        range:NSMakeRange(0, [dataResponse length])];
    return [matches count] != 0;
}


/**
 * Code Taken and modified from : git://gist.github.com/916845.git
 * Put a query string onto the end of a url
 */
- (NSString*)addQueryStringToUrl:(NSString*)url params:(NSDictionary *)params
{
    NSMutableString *urlWithQuerystring = [[NSMutableString alloc] initWithString:url];
    // Convert the params into a query string
    if (params)
    {
        BOOL first = true;
        for(id key in params)
        {
            NSString *sKey = [key description];
            NSString *sVal = [[params objectForKey:key] description];
            
            // Do we need to add k=v or &k=v ?
            if (first)
            {
                [urlWithQuerystring appendFormat:@"%@=%@",
                 [sKey stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                 [sVal stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                first = false ;
            }
            else
            {
                [urlWithQuerystring appendFormat:@"&%@=%@",
                 [sKey stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                 [sVal stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }
    return urlWithQuerystring;
}

- (void)setObjectIfNotNil:(id)object
                  forKey:(id<NSCopying>)key
           inDictionnary:(NSMutableDictionary*)dictionnary
{
    if(object != nil)
    {
        [dictionnary setObject:object forKey:key];
    }
}


#pragma mark - NSURLConnectionDelegateStuff

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    DDLogError(@"connection: %@ failed with error: %@", connection, error);
}


@end
