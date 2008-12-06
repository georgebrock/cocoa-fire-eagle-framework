//
//  FEXMLParser.h
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class FELocation;


@interface FEXMLParser : NSXMLParser
{
	BOOL inHierarchy;
	BOOL inList;
	BOOL inLocation;
	
	NSMutableArray *locations;
	FELocation *currentLocation;
	NSString *elementText;
	NSString *listQueryString;
	
	id resultingObject;
}

+ (id)parseString:(NSString*)xml;

- (id)resultingObject;

@end
