//
//  FEXMLParser.m
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FEXMLParser.h"
#import "FELocation.h"
#import "FELocationHierarchy.h"
#import "NSString+FEAdditions.h"

@implementation FEXMLParser

+ (id)parseString:(NSString*)xml
{
	id object = nil;

	// Create a parser instance to do the work
	FEXMLParser *parser = [[FEXMLParser alloc] initWithData:[xml dataUsingEncoding:NSUTF8StringEncoding]];
	[parser setDelegate:parser];
	
	// Parse the XML
	BOOL result = [parser parse];
	if(result)
		object = [parser resultingObject];
	
	// Tidy up
	[parser release], parser = nil;
	
	// Return the result
	return object;
}

- (void)dealloc
{
	[currentLocation release], currentLocation = nil;
	[locations release], locations = nil;
	[elementText release], elementText = nil;
	[listQueryString release], listQueryString = nil;
	[resultingObject release], resultingObject = nil;
	[super dealloc];
}

- (id)resultingObject
{
	return resultingObject;
}

- (void)parserDidStartDocument:(NSXMLParser *)parser
{
	inHierarchy = FALSE;
	inLocation = FALSE;
	[locations release], locations = nil;
	[currentLocation release], currentLocation = nil;
	[elementText release], elementText = nil;
	[listQueryString release], listQueryString = nil;
	[resultingObject release], resultingObject = nil;
}

- (void)parserDidEndDocument:(NSXMLParser *)parser
{		
	// Tidy up
	[locations release], locations = nil;
	[currentLocation release], currentLocation = nil;
	[elementText release], elementText = nil;
	[listQueryString release], listQueryString = nil;
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
	[elementText release], elementText = [@"" retain];
	
	if([elementName isEqual:@"err"])
	{
		NSString *errorMessage = [attributeDict objectForKey:@"msg"];
		NSString *errorCode = [attributeDict objectForKey:@"code"];
		
		resultingObject = [[[NSError alloc] initWithDomain:@"FEXMLParserErrorDomain" code:[errorCode intValue] userInfo:[NSDictionary dictionaryWithObject:errorMessage forKey:NSLocalizedDescriptionKey]] retain];
	}
	
	if([elementName isEqual:@"location-hierarchy"])
	{
		inHierarchy = TRUE;
		[locations release], locations = [[[NSMutableArray alloc] initWithCapacity:1] retain];
	}
	
	if([elementName isEqual:@"locations"])
	{
		inList = TRUE;
		int count = [[attributeDict objectForKey:@"count"] intValue];
		[locations release], locations = [[[NSMutableArray alloc] initWithCapacity:count] retain];
	}
	
	if([elementName isEqual:@"location"])
	{
		inLocation = TRUE;
		[currentLocation release], currentLocation = [[[FELocation alloc] init] retain];
		
		NSString *bestGuess = [attributeDict objectForKey:@"best-guess"];
		currentLocation.hierarchyBestGuess = (bestGuess && [bestGuess isEqual:@"true"]);
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if([elementName isEqual:@"location-hierarchy"])
	{
		inHierarchy = FALSE;
		resultingObject = [[[FELocationHierarchy alloc] initWithLocations:locations] retain];
		[locations release], locations = nil;
	}
	
	if([elementName isEqual:@"locations"])
	{
		inList = FALSE;
		resultingObject = [[[NSDictionary alloc] initWithObjectsAndKeys:
			locations, @"locations",
			[listQueryString queryStringComponents], @"query",
			nil] retain];
		[locations release], locations = nil;
		[listQueryString release], listQueryString = nil;
	}
	
	if([elementName isEqual:@"location"])
	{
		inLocation = FALSE;
		[locations addObject:currentLocation];
		[currentLocation release], currentLocation = nil;
	}
	
	if([elementName isEqual:@"querystring"])
	{
		listQueryString = [elementText retain];
	}
	
	if(inLocation)
	{
		if([elementName isEqual:@"name"])
			currentLocation.name = elementText;
			
		if([elementName isEqual:@"woeid"])
			currentLocation.WOEID = elementText;
		
		if([elementName isEqual:@"place-id"])
			currentLocation.placeID = elementText;
			
		if([elementName isEqual:@"level"])
			currentLocation.hierarchyLevel = [elementText intValue];
			
		if([elementName isEqual:@"level-name"])
			currentLocation.hierarchyLevelName = elementText;
			
		if([elementName isEqual:@"located-at"])
			currentLocation.time = [NSDate dateWithString:elementText];

		if([elementName isEqual:@"georss:box"])
		{
			NSArray *points = [elementText componentsSeparatedByString:@" "];
			
			currentLocation.geo = [[FEGeoRect alloc] 
				initWithSouthWestLat:[[points objectAtIndex:0] floatValue] 
				lng:[[points objectAtIndex:1] floatValue] 
				northEastLat:[[points objectAtIndex:2] floatValue] 
				lng:[[points objectAtIndex:3] floatValue]];
		}
		
		if([elementName isEqual:@"georss:point"])
		{
			NSArray *points = [elementText componentsSeparatedByString:@" "];
			currentLocation.geo = [[FEGeoRect alloc] 
				initWithSouthWestLat:[[points objectAtIndex:0] floatValue] 
				lng:[[points objectAtIndex:1] floatValue] 
				northEastLat:[[points objectAtIndex:0] floatValue] 
				lng:[[points objectAtIndex:1] floatValue]];
		}
		
		if([elementName isEqual:@"georss:poly"])
		{
			NSLog(@"We got us a polygon!\n%@", elementText);
		}
	}
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	NSString *newElementText = [NSString stringWithFormat:@"%@%@", elementText, string];
	[elementText release], elementText = [newElementText retain];
}

//- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
//- (void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validError

//- (void)parser:(NSXMLParser *)parser foundCDATA:(NSData *)CDATABlock
//- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString
//- (void)parser:(NSXMLParser *)parser didStartMappingPrefix:(NSString *)prefix toURI:(NSString *)namespaceURI
//- (void)parser:(NSXMLParser *)parser didEndMappingPrefix:(NSString *)prefix
//- (void)parser:(NSXMLParser *)parser foundComment:(NSString *)comment
//- (void)parser:(NSXMLParser *)parser foundProcessingInstructionWithTarget:(NSString *)target data:(NSString *)data
//- (NSData *)parser:(NSXMLParser *)parser resolveExternalEntityName:(NSString *)entityName systemID:(NSString *)systemID

//DTD methods:
//- (void)parser:(NSXMLParser *)parser foundAttributeDeclarationWithName:(NSString *)attributeName forElement:(NSString *)elementName type:(NSString *)type defaultValue:(NSString *)defaultValue
//- (void)parser:(NSXMLParser *)parser foundElementDeclarationWithName:(NSString *)elementName model:(NSString *)model
//- (void)parser:(NSXMLParser *)parser foundExternalEntityDeclarationWithName:(NSString *)entityName publicID:(NSString *)publicID systemID:(NSString *)systemID
//- (void)parser:(NSXMLParser *)parser foundInternalEntityDeclarationWithName:(NSString *)name value:(NSString *)value
//- (void)parser:(NSXMLParser *)parser foundUnparsedEntityDeclarationWithName:(NSString *)name publicID:(NSString *)publicID systemID:(NSString *)systemID notationName:(NSString *)notationName
//- (void)parser:(NSXMLParser *)parser foundNotationDeclarationWithName:(NSString *)name publicID:(NSString *)publicID systemID:(NSString *)systemID

@end
