//
//  FELocationHierarchy.h
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class FELocation;

@interface FELocationHierarchy : NSObject 
{
	NSArray *locations;
	int bestGuessIndex;
}

- (FELocationHierarchy*)initWithLocations:(NSArray*)locations;
- (NSArray*)locations;
- (FELocation*)bestGuess;

@end
