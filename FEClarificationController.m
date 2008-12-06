//
//  FEClarificationController.m
//  FireEagleClient
//
//  Created by George on 25/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FEClarificationController.h"
#import "FEClient.h"
#import "FELocation.h"


@implementation FEClarificationController

@synthesize client;

- (void)clarifyAndSetUserLocation:(NSDictionary*)locationData;
{
	if(!locationData)
		return;

	// Check there is more than one location in the response data
	NSArray *locationList = [locationData objectForKey:@"locations"];
	
	if(!locationList || [locationList count] == 0)
		return;
	
	if([locationList count] == 1)
	{
		FELocation *soloLocation = [locationList objectAtIndex:0];
		[client requestUserLocationChangeToAddress:soloLocation.name];
		return;
	}
	
	// Start pre-loading the images
	NSEnumerator *locEnum = [locationList objectEnumerator];
	FELocation *loc;
	while(loc = [locEnum nextObject])
		[loc lookupImage];
	
	// Populate the clarification panel's array controller
	[clarificationArrayController setContent:locationList];
	
	// Display the clarification panel
	NSWindow *keyWindow = [NSApp keyWindow];
	if(keyWindow)
		[NSApp beginSheet:clarificationPanel modalForWindow:keyWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
	else
		[clarificationPanel makeKeyAndOrderFront:self];
}

- (IBAction)setLocationFromClarificationList:(id)sender
{
	// Get the selected location
	FELocation *selectedLocation = [[clarificationArrayController selectedObjects] objectAtIndex:0];

	NSDictionary *location;
	if(selectedLocation.WOEID)
		location = [NSDictionary dictionaryWithObject:selectedLocation.WOEID forKey:FELocationWOEIDKey];
	else
		location = [NSDictionary dictionaryWithObject:selectedLocation.name forKey:FELocationAddressKey];
		
	// Send the location back to the Fire Eagle client
	[client requestUserLocationChange:location];
	
	// Close clarification interface
    [clarificationPanel orderOut:nil];
    [NSApp endSheet:clarificationPanel];
}

- (IBAction)cancelClarification:(id)sender
{
    [clarificationPanel orderOut:nil];
    [NSApp endSheet:clarificationPanel];
}

@end
