//
//  FEClient.h
//  FireEagleClient
//
//  Created by George on 30/05/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FEConstants.h"

@class 
	FEXMLParser, 
	FELocation, FELocationHierarchy,
	FEClarificationController, FEAuthController;

@interface FEClient : NSObject 
{
	IBOutlet id delegate;

	NSString *applicationName;
	NSString *consumerKey;
	NSString *consumerSecret;

	NSString *accessToken;
	NSString *accessTokenSecret;
	
	NSString *requestToken;
	NSString *requestTokenSecret;
	
	FEClarificationController *clarificationController;
	FEAuthController *authController;
	
	int working;
	BOOL useKeychain;
}

@property BOOL useKeychain;
@property(readwrite,assign) NSString *applicationName;

// Set up Fire Eagle values
- (void)setConsumerKey:(NSString*)newKey secret:(NSString*)newSecret;
- (void)setAccessToken:(NSString*)newToken secret:(NSString*)newSecret;

// Set a delegate to handle Fire Eagle's responses
- (void)setDelegate:(id)newDelegate;

// Fire Eagle authentication
- (void)authenticate;
- (BOOL)isAuthorised;

// Asynchronous Fire Eagle API calls
- (void)requestUserLocation;
- (void)requestLocationLookupFromAddress:(NSString*)address;
- (void)requestLocationLookup:(NSDictionary*)location;
- (void)requestUserLocationChange:(NSDictionary*)location;
- (void)requestUserLocationChangeToAddress:(NSString*)address;

// Synchronous Fire Eagle API calls
- (FELocationHierarchy*)userLocation;
- (NSDictionary*)locationLookupFromAddress:(NSString*)address;
- (NSDictionary*)locationLookup:(NSDictionary*)location;
- (BOOL)setUserLocationToAddress:(NSString*)newAddress;
- (BOOL)setUserLocation:(NSDictionary*)newLocation;

// Misc
- (void)clarifyAndSetUserLocation:(NSString*)newLocation;
- (BOOL)isWorking;

@end
