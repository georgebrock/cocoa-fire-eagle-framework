//
//  FELocation.h
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FEGeoRect.h"

@interface FELocation : NSObject 
{
	NSString *name;
	FEGeoRect *geo;
	NSPoint southWest;
	NSPoint northEast;
	NSString *placeID;
	NSString *WOEID;
	NSDate *time;
	NSImage *image;
	
	BOOL hierarchyBestGuess;
	int hierarchyLevel;
	NSString *hierarchyLevelName;
}

@property(retain, readwrite) NSString *name;
@property(retain, readwrite) FEGeoRect *geo;
@property(retain, readwrite) NSString *placeID;
@property(retain, readwrite) NSString *WOEID;
@property(retain, readwrite) NSDate *time;

@property(assign, readwrite) BOOL hierarchyBestGuess;
@property(assign, readwrite) int hierarchyLevel;
@property(retain, readwrite) NSString *hierarchyLevelName;

- (void)lookupImage;
- (NSImage*)image;

@end
