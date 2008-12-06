//
//  FEGeoRect.h
//  FireEagleClient
//
//  Created by George on 26/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FEGeoRect : NSObject 
{
	float southWestLongitude;
	float southWestLatitude;
	float northEastLongitude;
	float northEastLatitude;
}

- (FEGeoRect*)initWithSouthWestLat:(float)swLat lng:(float)swLng northEastLat:(float)neLat lng:(float)neLng;

- (void)setSouthWestLat:(float)swLat lng:(float)swLng;
- (void)setSouthWestLat:(float)neLat lng:(float)neLng;

- (NSSize)size;

- (float)centroidLatitude;
- (float)centroidLongitude;

@end
