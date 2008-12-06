//
//  FEGeoAPI.m
//  FireEagleClient
//
//  Created by George on 03/07/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FEGeoAPI.h"
#import "FEGeoRect.h"

//TODO: Experiment with a static variable for caching images
//static NSDictionary *FEGeoMapCache;
static NSString *FEGeoAPIKey = nil;

@interface FEGeoAPI (Private)
+ (void)doTerminate;
@end

@implementation FEGeoAPI

+ (void)setAPIKey:(NSString*)key
{
	[FEGeoAPIKey release],
	FEGeoAPIKey = [key retain];
	
	NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
	[ns removeObserver:[FEGeoAPI class]];
	[ns addObserver:[FEGeoAPI class] selector:@selector(doTerminate) name:NSApplicationWillTerminateNotification object:NSApp];
}

+ (void)doTerminate
{
	if(FEGeoAPIKey)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:[FEGeoAPI class]];
		[FEGeoAPIKey release], FEGeoAPIKey = nil;
	}
}

+ (NSURL*)mapURLForGeoRect:(FEGeoRect*)rect size:(NSSize)size error:(NSError**)err
{
	// Figure out the map radius
	NSSize geoSize = [rect size];
	float rad = (geoSize.width > geoSize.height ? geoSize.width : geoSize.height) / 2.0;
	if(rad < 0.1)
		rad = 0.1;
	
	// Request the map XML from the maps API
	NSURL *mapURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://local.yahooapis.com/MapsService/V1/mapImage?appid=%@&latitude=%f&longitude=%f&radius=%f&image_height=%d&image_width=%d", FEGeoAPIKey, [rect centroidLatitude], [rect centroidLongitude], rad, (int)size.height, (int)size.width]];
	NSURLRequest *mapURLReq = [NSURLRequest requestWithURL:mapURL];
	NSData *downloadData = [NSURLConnection sendSynchronousRequest:mapURLReq returningResponse:NULL error:NULL];
	NSString *mapXML = [[NSString alloc] initWithData:downloadData encoding:NSUTF8StringEncoding];
	
	// Scan the map XML to get the image URL
	NSString *imageURLString = nil;
	NSScanner *scanner = [NSScanner scannerWithString:mapXML];
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@">"]];
	
	BOOL scanResult = TRUE;
	scanResult = scanResult && [scanner scanUpToString:@">http://" intoString:NULL];
	scanResult = scanResult && [scanner scanUpToString:@"<" intoString:&imageURLString];		
	
	// Fail if the map API doesn't give us a URL
	if(!scanResult)
	{
		NSLog(@"Giving up, bad Yahoo! Maps API juju\n%@", mapXML);
		//TODO: Set the error
		return nil;
	}
	
	// Convert the image URL to a URL object
	return [NSURL URLWithString:imageURLString];
}

+ (FEGeoRect*)geoRectForWOEID:(NSString*)WOEID error:(NSError**)err
{
	// Fetch the place description from the Yahoo Geo API
	NSURL *placeURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://where.yahooapis.com/v1/place/%@?appid=%@", WOEID, FEGeoAPIKey]];
	NSURLRequest *placeURLReq = [NSURLRequest requestWithURL:placeURL];
	NSData *downloadData = [NSURLConnection sendSynchronousRequest:placeURLReq returningResponse:NULL error:NULL];
	NSString *placeXML = [[NSString alloc] initWithData:downloadData encoding:NSUTF8StringEncoding];
	
	// Scan the place to get longitude, latitude etc.
	float crLat, crLng, swLat, swLng, neLat, neLng;
	NSScanner *scanner = [NSScanner scannerWithString:placeXML];
	BOOL scanResult = TRUE;

	scanResult = scanResult && [scanner scanUpToString:@"<centroid><latitude>" intoString:NULL];	
	scanResult = scanResult && [scanner scanString:@"<centroid><latitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanFloat:&crLat];
	scanResult = scanResult && [scanner scanString:@"</latitude><longitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanFloat:&crLng];
	
	[scanner setScanLocation:0];
	scanResult = scanResult && [scanner scanUpToString:@"<southWest><latitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanString:@"<southWest><latitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanFloat:&swLat];
	scanResult = scanResult && [scanner scanString:@"</latitude><longitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanFloat:&swLng];
	
	[scanner setScanLocation:0];
	scanResult = scanResult && [scanner scanUpToString:@"<northEast><latitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanString:@"<northEast><latitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanFloat:&neLat];
	scanResult = scanResult && [scanner scanString:@"</latitude><longitude>" intoString:NULL];
	scanResult = scanResult && [scanner scanFloat:&neLng];
	
	if(!scanResult)
	{
		NSLog(@"Giving up, bad Yahoo! Geo API juju\n%@", placeXML);
		//TODO: Set the error
		return nil;
	}
	
	// Populate self.geo from the data returned by the API call
	FEGeoRect *geo = [[[FEGeoRect alloc] initWithSouthWestLat:swLat lng:swLng northEastLat:neLat lng:neLng] autorelease];
	return geo;
}

/*

<place xmlns="http://where.yahooapis.com/v1/schema.rng" xmlns:yahoo="http://www.yahooapis.com/v1/base.rng" yahoo:uri="http://where.yahooapis.com/v1/place/44418" xml:lang="en-us">
	<woeid>44418</woeid>
	<placeTypeName code="7">Town</placeTypeName>
	<name>London</name>
	<country type="Country" code="GB">United Kingdom</country>
	<admin1 type="Country" code="">England</admin1>
	<admin2 type="County" code="GB-LND">Greater London</admin2>
	<admin3></admin3>
	<locality1 type="Town">London</locality1>
	<locality2></locality2>
	<postal></postal>
	<centroid>
		<latitude>51.506321</latitude>
		<longitude>-0.12714</longitude>
	</centroid>
	<boundingBox>
		<southWest>
			<latitude>51.261318</latitude>
			<longitude>-0.50901</longitude>
		</southWest>
		<northEast>
			<latitude>51.686031</latitude>
			<longitude>0.28036</longitude>
		</northEast>
	</boundingBox>
</place>

*/

@end
