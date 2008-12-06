//
//  FELocation.m
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FELocation.h"
#import "FEGeoAPI.h"


@interface FELocation (Private)
- (void)lookupImageThreadMain;
@end


@implementation FELocation

@synthesize name, geo, placeID, WOEID, time;
@synthesize hierarchyBestGuess, hierarchyLevel, hierarchyLevelName;

- (void)dealloc
{
	[name release], name = nil;
	[placeID release], placeID = nil;
	[WOEID release], WOEID = nil;
	[time release], time = nil;
	[hierarchyLevelName release], hierarchyLevelName = nil;
	[image release], image = nil;
	
	[super dealloc];
}

- (void)lookupImageThreadMain
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Set the "loading" image in case we have a lot of work to do
	if(!image)
	{
		[self performSelectorOnMainThread:@selector(willChangeValueForKey:) withObject:@"image" waitUntilDone:TRUE];
		image = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"loading" ofType:@"gif"]] retain];
		[self performSelectorOnMainThread:@selector(didChangeValueForKey:) withObject:@"image" waitUntilDone:TRUE];
	}
	
	// Look up GeoRect from WOEID if required
	if(!self.geo && self.WOEID)
		self.geo = [FEGeoAPI geoRectForWOEID:self.WOEID error:nil];
	
	// Get the image URL
	NSURL *imageURL = nil;
	if(self.geo)
		imageURL = [FEGeoAPI mapURLForGeoRect:self.geo size:NSMakeSize(300, 200) error:NULL];
	
	// Update the image
	[self willChangeValueForKey:@"image"];
	if(imageURL)
	{
		// Load the image from the URL we got from the Geo API
		[image release],
		image = [[[NSImage alloc] initWithContentsOfURL:imageURL] retain];
	}
	else
	{
		// Set the "unavailable" image if we've failed
		NSLog(@"Giving up, no Geo even after attempting lookup from WOEID");
		[image release],
		image = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"unavailable" ofType:@"png"]] retain];
	}
	[self didChangeValueForKey:@"image"];
	
	// Tidy up
	[pool release];
}

- (void)lookupImage
{
	[NSThread detachNewThreadSelector:@selector(lookupImageThreadMain) toTarget:self withObject:nil];
}

- (NSImage*)image
{
	if(!image)
		[self lookupImage];
	
	return image;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"<FElocation name:\"%@\" geo:%@ placeID:%@ WOEID:%@>", name, geo, placeID, WOEID];
}

@end
