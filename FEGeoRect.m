//
//  FEGeoRect.m
//  FireEagleClient
//
//  Created by George on 26/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FEGeoRect.h"


@implementation FEGeoRect

- (FEGeoRect*)initWithSouthWestLat:(float)swLat lng:(float)swLng northEastLat:(float)neLat lng:(float)neLng
{
	self = [super init];
	if(!self)
		return self;
		
	southWestLatitude = swLat;
	southWestLongitude = swLng;
	northEastLatitude = neLat;
	northEastLongitude = neLng;
	
	return self;
}

- (void)setSouthWestLat:(float)swLat lng:(float)swLng
{
	southWestLatitude = swLat;
	southWestLongitude = swLng;
}

- (void)setNorthEastLat:(float)neLat lng:(float)neLng
{
	northEastLatitude = neLat;
	northEastLongitude = neLng;
}

- (NSSize)size
{
	float centroidLatitude = northEastLatitude - southWestLatitude;

	float width = (northEastLongitude - southWestLongitude) * cos(centroidLatitude * 0.0174532925) * 69.172;
	float height = (northEastLatitude - southWestLatitude) * 69.172;
	
	return NSMakeSize(width, height);
}

- (float)centroidLatitude
{
	return (southWestLatitude + northEastLatitude) / 2;
}

- (float)centroidLongitude
{
	return (southWestLongitude + northEastLongitude) / 2;
}

- (NSString*)description
{
	if(southWestLatitude == northEastLatitude && southWestLongitude == northEastLongitude)
		return [NSString stringWithFormat:@"<georss:point>%f %f</georss:point>", southWestLatitude, southWestLongitude];
		
	return [NSString stringWithFormat:@"<georss:box>%f %f %f %f</georss:box>", southWestLatitude, southWestLongitude, northEastLatitude, northEastLongitude];
}

@end
