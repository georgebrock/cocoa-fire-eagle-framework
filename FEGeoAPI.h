//
//  FEGeoAPI.h
//  FireEagleClient
//
//  Created by George on 03/07/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class FEGeoRect;


@interface FEGeoAPI : NSObject 

+ (void)setAPIKey:(NSString*)key;
+ (NSURL*)mapURLForGeoRect:(FEGeoRect*)rect size:(NSSize)size error:(NSError**)err;
+ (FEGeoRect*)geoRectForWOEID:(NSString*)WOEID error:(NSError**)err;

@end
