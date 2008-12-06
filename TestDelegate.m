//
//  TestDelegate.m
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "TestDelegate.h"
#import "CocoaFireEagle.h"

@implementation TestDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[mainWindow makeKeyAndOrderFront:nil];
	if(![fireEagle isAuthorised])
		[fireEagle authenticate];
}

- (void)awakeFromNib
{
	[FEGeoAPI setAPIKey:@"i5h72sfV34GPaLxKMX3HRdla8mkjFXc29BYnHI.cRgAinEKtsYy6TA2iCBmKCaNnltoNKukvkcl5lVk-"];

	fireEagle.useKeychain = TRUE;
	fireEagle.applicationName = @"Fire Eagle Cocoa Framework Test Application";
	[fireEagle setConsumerKey:@"VaTSwF8e5Cun" secret:@"bgwUxBXq7UBSLekBZ0v8UmS6nG1Ocvdh"];
		
	//[fireEagle setAccessToken:@"hGamh5hqu9f3" secret:@"cnC0iJvvPKGP2Rmezd7b8mhpxMKNtVvh"];
}

- (IBAction)authorise:(id)sender
{
	[fireEagle authenticate];
}

- (IBAction)lookup:(id)sender
{
	[fireEagle requestLocationLookupFromAddress:[inputField stringValue]];
}

- (IBAction)setLocation:(id)sender
{
	[fireEagle clarifyAndSetUserLocation:[inputField stringValue]];
}

- (IBAction)getLocation:(id)sender
{
	[fireEagle requestUserLocation];
}



// ============================================================================
// ==================== FIRE EAGLE CLIENT DELEGATE METHODS ====================
// ============================================================================

- (void)fireEagleClientWasAuthorised:(FEClient*)client
{
	[client requestUserLocation];
}

- (void)fireEagleClient:(FEClient*)client recievedUserLocation:(FELocationHierarchy*)locationHierarchy
{
	NSMutableString *str = [NSMutableString stringWithCapacity:10];
	
	[currentLocationController setContent:locationHierarchy];
	
	NSEnumerator *locEnum = [[locationHierarchy locations] objectEnumerator];
	FELocation *loc;
	while(loc = [locEnum nextObject])
		[str appendFormat:@"%d. %@ (%@)\n", loc.hierarchyLevel, loc.name, loc.hierarchyLevelName];
	
	[outputField setString:str];
}

- (void)fireEagleClient:(FEClient*)client recievedLocationList:(NSDictionary*)locationData
{
	NSMutableString *str = [NSMutableString stringWithCapacity:10];
	
	[str appendFormat:@"%@\n\n", [locationData objectForKey:@"query"]];
	
	NSEnumerator *locEnum = [[locationData objectForKey:@"locations"] objectEnumerator];
	FELocation *loc;
	while(loc = [locEnum nextObject])
		[str appendFormat:@"%@ (%@ / %@)\n", loc.name, loc.WOEID, loc.geo];
	
	[outputField setString:str];
}

- (void)fireEagleClientUpdatedUserLocation:(FEClient*)client
{
	[outputField setString:@"User location updated!"];
	[self getLocation:self];
}

- (void)fireEagleClient:(FEClient*)client experiencedError:(NSError*)error
{
	[outputField setString:[NSString stringWithFormat:@"Fire eagle error: %@", error]];
}

@end
