//
//  FELocationHierarchy.m
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FELocationHierarchy.h"
#import "FELocation.h"

@implementation FELocationHierarchy

- (FELocationHierarchy*)init
{
	self = [super init];
	if(!self)
		return nil;
		
	locations = nil;
	bestGuessIndex = -1;
	
	return self;
}

- (FELocationHierarchy*)initWithLocations:(NSArray*)newLocations
{
	self = [super init];
	if(!self)
		return nil;
	
	locations = [newLocations retain];
	
	[self willChangeValueForKey:@"bestGuess"];
	bestGuessIndex = -1;
	
	int i;
	for(i = 0; i < [locations count]; i++)
	{
		if(((FELocation*)[locations objectAtIndex:i]).hierarchyBestGuess)
		{
			bestGuessIndex = i;
			break;
		}
	}
	[self didChangeValueForKey:@"bestGuess"];
	
	return self;
}

- (void)dealloc
{
	[locations release], locations = nil;
	[super dealloc];
}

- (NSArray*)locations
{
	return locations;
}

- (FELocation*)bestGuess
{
	if(bestGuessIndex < 0)
		return nil;
	
	return [locations objectAtIndex:bestGuessIndex];
}

@end
