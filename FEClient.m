//
//  FEClient.m
//  FireEagleClient
//
//  Created by George on 30/05/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FEClient.h"
#import <Security/Security.h>

#import "NSString+FEAdditions.h"
#import "FEXMLParser.h"
#import "FELocationHierarchy.h"
#import "FELocation.h"
#import "FEClarificationController.h"
#import "FEAuthController.h"
#import "FEGeoAPI.h"

#define FE_DEFAULT_APP_NAME @"this application"

@interface FEClient (Private)

- (NSString*)callURL:(NSString*)url withArguments:(NSDictionary*)arguments usePOST:(BOOL)post;
- (void)handleError:(NSError*)err;
- (BOOL)requestAccessToken;

- (void)requestUserLocationThreadMain;
- (void)requestLocationLookupThreadMain:(NSDictionary*)location;
- (void)requestUserLocationChangeThreadMain:(NSDictionary*)location;

- (void)getRequestTokenThreadMain;
- (void)clarifyAndSetUserLocationThreadMain:(NSString*)newLocation;

- (void)incrementWorking;
- (void)decrementWorking;

- (void)storeAccessTokenInKeychain;
- (void)retrieveAccessTokenFromKeychain;
- (void)removeAccessTokenFromKeychain;

@end

@implementation FEClient

@synthesize 
	useKeychain, 
	applicationName;

// ===========================================================================
// ============================= GENERAL METHODS =============================
// ===========================================================================

- (id)init
{
	self.applicationName = FE_DEFAULT_APP_NAME;
	return self;
}

- (void)awakeFromNib
{
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[delegate release], delegate = nil;

	[consumerKey release], consumerKey = nil;
	[consumerSecret release], consumerSecret = nil;
	
	[accessToken release], accessToken = nil;
	[accessTokenSecret release], accessTokenSecret = nil;
	
	[requestToken release], requestToken = nil;
	[requestTokenSecret release], requestTokenSecret = nil;
	
	[clarificationController release], clarificationController = nil;
	
	[super dealloc];
}

- (void)setConsumerKey:(NSString*)newKey secret:(NSString*)newSecret
{
	[consumerKey release], consumerKey = [newKey retain];
	[consumerSecret release], consumerSecret = [newSecret retain];
	
	if(consumerKey && consumerSecret && self.useKeychain)
		[self retrieveAccessTokenFromKeychain];
}

- (void)setAccessToken:(NSString*)newToken secret:(NSString*)newSecret
{
	[self willChangeValueForKey:@"authorised"];
	[accessToken release], accessToken = [newToken retain];
	[accessTokenSecret release], accessTokenSecret = [newSecret retain];
	[self didChangeValueForKey:@"authorised"];
	
	if(accessToken && accessTokenSecret)
	{
		if(self.useKeychain)
			[self storeAccessTokenInKeychain];
		
		if(delegate && [delegate respondsToSelector:@selector(fireEagleClientWasAuthorised:)])
			[delegate performSelector:@selector(fireEagleClientWasAuthorised:) withObject:self];
	}
}

- (void)setDelegate:(id)newDelegate
{
	[delegate release], delegate = [newDelegate retain];
}

- (void)handleError:(NSError*)err
{
	// If the authentication interface is visible use it to display the error
	if(authController && [authController isInterfaceVisible])
		[authController authenticationError:[[err userInfo] objectForKey:NSLocalizedDescriptionKey]];

	if(delegate && [delegate respondsToSelector:@selector(fireEagleClient:experiencedError:)])
		[delegate performSelector:@selector(fireEagleClient:experiencedError:) withObject:self withObject:err];
	else
	{
		NSAlert *errAlert = [NSAlert alertWithError:err];
		[errAlert runModal];
	}
}

- (BOOL)isAuthorised
{
	return accessToken && accessTokenSecret;
}


// ===========================================================================
// ============================== OAUTH METHODS ==============================
// ===========================================================================

- (NSString*)callURL:(NSString*)url withArguments:(NSDictionary*)arguments usePOST:(BOOL)post
{
	// Make sure we know the consumer key of the application we're using
	if(!consumerKey || !consumerSecret)
	{
		[self handleError:[NSError 
			errorWithDomain:@"FEClientErrorDomain" 
			code:20 // Fire Eagle error code for no consumer key
			userInfo:[NSDictionary dictionaryWithObject:@"Consumer key and/or consumer secret is not set" forKey:NSLocalizedDescriptionKey]]];
		return nil;
	}

	// Work out a timestamp and associated nonce
	NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
	NSString *nonce = [[NSString stringWithFormat:@"%d%d", timestamp, rand()] MD5Hash];

	// Build dictionary of arguments
	NSMutableDictionary *queryStringArguments = [[NSMutableDictionary alloc] initWithCapacity:5];
	[queryStringArguments setObject:consumerKey forKey:@"oauth_consumer_key"];
	[queryStringArguments setObject:nonce forKey:@"oauth_nonce"];
	[queryStringArguments setObject:@"HMAC-SHA1" forKey:@"oauth_signature_method"];
	[queryStringArguments setObject:[NSString stringWithFormat:@"%.0f", timestamp] forKey:@"oauth_timestamp"];
	[queryStringArguments setObject:@"1.0" forKey:@"oauth_version"];
	
	// Add the current token, if we've got one
	if(accessToken)
		[queryStringArguments setObject:accessToken forKey:@"oauth_token"];
	else if(requestToken)
		[queryStringArguments setObject:requestToken forKey:@"oauth_token"];
		
	// Add anything extra from the arguments dictionary
	if(arguments)
	{
		NSEnumerator *argKeyEnumerator = [[arguments allKeys] objectEnumerator];
		NSString *argKey;
		while(argKey = [argKeyEnumerator nextObject])
		{
			NSString *argString = (NSString*)[arguments objectForKey:argKey];
			NSString *escapedArgString = (NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)argString, NULL, (CFStringRef)@"&=:/,", kCFStringEncodingASCII);
		
			[queryStringArguments setObject:escapedArgString forKey:argKey];
		}
	}
		
	// Build the query string with the terms in alphabetical order
	NSArray *queryStringKeys = [[queryStringArguments allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	NSMutableArray *queryStringTerms = [[NSMutableArray alloc] initWithCapacity:[queryStringKeys count]];
	NSEnumerator *qsEnum = [queryStringKeys objectEnumerator];
	NSString *qsKey;
	while(qsKey = (NSString*)[qsEnum nextObject])
		[queryStringTerms addObject:[NSString stringWithFormat:@"%@=%@", qsKey, [queryStringArguments objectForKey:qsKey]]];
	NSString *queryString = [queryStringTerms componentsJoinedByString:@"&"];
	[queryStringTerms release], queryStringTerms = nil;
		
	// Work out the signature
	NSString *baseString = [NSString stringWithFormat:@"%@&%@&%@", 
		post ? @"POST" : @"GET",
		CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)url, NULL, (CFStringRef)@"&=:/,", kCFStringEncodingASCII),
		CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)queryString, NULL, (CFStringRef)@"&=,", kCFStringEncodingASCII)];
		
	NSString *secondSecret = @"";
	if(accessTokenSecret)
		secondSecret = accessTokenSecret;
	else if(requestTokenSecret)
		secondSecret = requestTokenSecret;
	
	NSString *key = [NSString stringWithFormat:@"%@&%@", consumerSecret, secondSecret];
	NSString *signature = [baseString SHA1HMACWithKey:key];
	
	queryString = [queryString stringByAppendingString:[NSString stringWithFormat:@"&oauth_signature=%@", 
			CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)signature, NULL, (CFStringRef)@"&/=+,", kCFStringEncodingASCII)
		]];
		
	NSURLRequest *urlReq;
	if(post)
	{
		NSMutableURLRequest *postRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
		[postRequest setHTTPMethod:@"POST"];
		[postRequest setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];
		urlReq = postRequest;
	}
	else
	{
		NSString *fullURL = [NSString stringWithFormat:@"%@?%@", url, queryString];
		urlReq = [NSURLRequest requestWithURL:[NSURL URLWithString:fullURL]];
	}
	
	//NSLog(@"URL: %@\nData: %@\nMethod: %@", [urlReq URL], queryString, (post ? @"POST" : @"GET"));
	
	// Grab the data from the FE server
	NSHTTPURLResponse *downloadResponse;
	NSError *downloadError;
	NSData *downloadData;
	downloadData = [NSURLConnection sendSynchronousRequest:urlReq returningResponse:&downloadResponse error:&downloadError];
	
	// Check for errors
	if(downloadError)
	{
		[self handleError:downloadError];
		return nil;
	}
	
	// Check the download worked correctly
	if([downloadResponse statusCode] != 200)
	{
		[self handleError:[NSError 
			errorWithDomain:@"FEClientErrorDomain" 
			code:[downloadResponse statusCode] 
			userInfo:[NSDictionary dictionaryWithObject:@"Bad response code from Fire Eagle" forKey:NSLocalizedDescriptionKey]]];
		
		return nil;
	}
	
	// Convert the downloaded data to a string
	NSString *download = [[NSString alloc] initWithData:downloadData encoding:NSUTF8StringEncoding];
	
	//NSLog(@"%@", download);
	
	// Check the string for Fire Eagle error XML
	NSString *status = nil;
	NSScanner *scanner = [NSScanner scannerWithString:download];
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
	[scanner scanUpToString:@"<rsp stat=" intoString:NULL];
	[scanner scanUpToString:@"\"" intoString:NULL];
	[scanner scanUpToString:@"\"" intoString:&status];

	if([status isEqual:@"fail"])
	{
		NSError *err = [FEXMLParser parseString:download];
		
		//TODO: figure out appropriate actions for each error code
		
		// ERROR CODES:
		//   1	User does not allow this app to perform updates											Send to: http://fireeagle.yahoo.net/my/apps
		//   2	Update worked, but user does not allow this app to read location						Send to: http://fireeagle.yahoo.net/my/apps
		//   3	User does not allow this app to read location											Send to: http://fireeagle.yahoo.net/my/apps
		//	 4	Account suspended; User must go to FireEagle											Send to: http://fireeagle.yahoo.net/
		//	 5	
		//	 6	Place can't be identified																User error
		//	 7	Token can't be matched to user; User may need to re-auth								Authenticate
		//	 8	Not all required params for location update												Programmer error
		//	 9	
		//	10	Request token used when Access token should have been used								Framework error
		//	11	Request token not validated; Can't get Access token before user authorisation			Framework error
		//	12	Request or General token used when Access token should have been used					Framework error
		//	13	Request token has expired (> 1 hour old)												User error
		//	14	Token provided must be a General Purpose token											?
		//	15	Unknown consumer key																	Programmer error
		//	16	Token not found; Could be that the user has unsubscribed								Authenticate
		//	17	
		//	18
		//	19
		//	20	oauth_consumer_key is missing															Framework error
		//	21	oauth_token is missing																	Framework error
		//	22	Unsupported signature method															Framework error
		//	23	Invalid OAuth signature																	Framework error
		//	24	Provided nonce has been seen before														Framework error
		//	25
		//	26
		//	27
		//	28
		//	29
		//	30	Use fireeagle.yahooapis.com for api methods												Framework error
		//	31	SSL required, this method must be requested with https									Framework error
		//	32	Rate limit/IP Block due to excessive requests											Excessive use (> 6 per minute for 1 hour+)
		
		[self handleError:err];
		return nil;
	}

	// Tidy up after ourselves
	[queryStringArguments release], queryStringArguments = nil;
	
	return [download autorelease];
}

- (void)getRequestTokenThreadMain
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// Ask for a Request Token
	NSLog(@"Asking for the request token...");
	NSString *url = @"https://fireeagle.yahooapis.com/oauth/request_token";
	NSString *download = [self callURL:url withArguments:nil usePOST:FALSE];
	
	NSLog(@"Request token: %@", download);
	
	// Extract the data from the download string
	NSDictionary *dict = [download queryStringComponents];
	
	// Store the new Request Token
	[requestToken release], 
	requestToken = [[dict objectForKey:@"oauth_token"] retain];
	[requestTokenSecret release],
	requestTokenSecret = [[dict objectForKey:@"oauth_token_secret"] retain];
	
	// Handle a lack of token
	if(!requestToken || !requestTokenSecret)
	{
		NSLog(@"Argh! No request token! (F.E. response: %@)\nTrying again...", download);
		[NSThread detachNewThreadSelector:@selector(getRequestTokenThreadMain) toTarget:self withObject:nil];
	}
	else
	{
		// Tell the authorisation controller to begin authorisation
		[authController performSelectorOnMainThread:@selector(authenticateWithToken:) withObject:requestToken waitUntilDone:FALSE];
	}
	
	[pool release];
}

- (void)authenticate
{
	if(!authController)
	{
		authController = [[[FEAuthController alloc] init] retain];
		authController.client = self;
		[NSBundle loadNibNamed:@"FEAuthorisation" owner:authController];
	}
	
	[authController beginAuthentication];
	
	[NSThread detachNewThreadSelector:@selector(getRequestTokenThreadMain) toTarget:self withObject:nil];
}

- (BOOL)requestAccessToken
{
	// Check for a request token
	if(!requestToken || !requestTokenSecret)
	{
		[self authenticate];
		return FALSE;
	}

	NSLog(@"Asking for an access token...");

	// Ask Fire Eagle for a token
	NSString *download = [self callURL:@"https://fireeagle.yahooapis.com/oauth/access_token" withArguments:nil usePOST:FALSE];

	// Extract the data from the download string
	NSDictionary *dict = [download queryStringComponents];
	
	// Store the new token
	[self setAccessToken:[dict objectForKey:@"oauth_token"] secret:[dict objectForKey:@"oauth_token_secret"]];
	
	// Display an error if we've not got a token
	if(!accessToken || !accessTokenSecret)
	{
		NSLog(@"Argh! No access token!\n%@", download);
	
		[self handleError:[NSError 
			errorWithDomain:@"FEClientErrorDomain" 
			code:0
			userInfo:[NSDictionary dictionaryWithObject:@"Access Token requested for but not returned" forKey:NSLocalizedDescriptionKey]]];
			
		return FALSE;
	}
	
	return TRUE;
}


// ===========================================================================
// ====================== PUBLIC FIRE EAGLE API METHODS ======================
// ===========================================================================

/**
 * Asynchronous method to request the user's location from Fire Eagle
 * The resulting FELocationHierarchy will be sent to the delegate's fireEagleClient:recievedUserLocation: method
 */
- (void)requestUserLocation
{
	[NSThread detachNewThreadSelector:@selector(requestUserLocationThreadMain) toTarget:self withObject:nil];
}

- (void)requestUserLocationThreadMain
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self incrementWorking];

	FELocationHierarchy *locHierarchy = [self userLocation];
	
	if(locHierarchy)
	{
		if(delegate && [delegate respondsToSelector:@selector(fireEagleClient:recievedUserLocation:)])
			[delegate performSelector:@selector(fireEagleClient:recievedUserLocation:) withObject:self withObject:locHierarchy];
	}
	
	[self decrementWorking];
	[pool release];
}

/**
 * Asynchronous method to lookup the possible interpretations of an address
 * The resulting NSDictionary of locations will be sent to the delegate's fireEagleClient:recievedLocationList: method
 */
- (void)requestLocationLookupFromAddress:(NSString*)address
{
	[NSThread 
		detachNewThreadSelector:@selector(requestLocationLookupThreadMain:) 
		toTarget:self 
		withObject:[NSDictionary dictionaryWithObject:address forKey:FELocationAddressKey]];
}

- (void)requestLocationLookup:(NSDictionary*)location
{
	[NSThread 
		detachNewThreadSelector:@selector(requestLocationLookupThreadMain:) 
		toTarget:self 
		withObject:location];
}

- (void)requestLocationLookupThreadMain:(NSDictionary*)location
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self incrementWorking];

	NSDictionary *locList = [self locationLookup:location];
	
	if(locList)
	{
		if(delegate && [delegate respondsToSelector:@selector(fireEagleClient:recievedLocationList:)])
			[delegate performSelector:@selector(fireEagleClient:recievedLocationList:) withObject:self withObject:locList];
	}
	
	[self decrementWorking];
	[pool release];
}

/**
 * Asynchronous method to update the user's location
 * If the user's location is updated sucessfully the delegate's fireEagleClientUpdatedUserLocation: method will be called
 */
- (void)requestUserLocationChange:(NSDictionary*)location
{
	[NSThread 
		detachNewThreadSelector:@selector(requestUserLocationChangeThreadMain:) 
		toTarget:self 
		withObject:location];
}

- (void)requestUserLocationChangeToAddress:(NSString*)address
{
	[NSThread 
		detachNewThreadSelector:@selector(requestUserLocationChangeThreadMain:) 
		toTarget:self 
		withObject:[NSDictionary dictionaryWithObject:address forKey:FELocationAddressKey]];
}

- (void)requestUserLocationChangeThreadMain:(NSDictionary*)location
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self incrementWorking];

	BOOL result = [self setUserLocation:location];

	if(result && delegate && [delegate respondsToSelector:@selector(fireEagleClientUpdatedUserLocation:)])
		[delegate performSelector:@selector(fireEagleClientUpdatedUserLocation:) withObject:self];
		
	[self decrementWorking];
	[pool release];
}


/**
 * Synchronous method to retrieve the user's location from Fire Eagle
 */
- (FELocationHierarchy*)userLocation
{
	if(![self isAuthorised])
	{
		[self handleError:[NSError 
			errorWithDomain:@"FEClientErrorDomain" 
			code:21 // Fire Eagle error code for no oauth token
			userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"You must allow %@ access to your Fire Eagle data before it can access your location", self.applicationName] forKey:NSLocalizedDescriptionKey]]];
		return nil;
	}

	NSString *locationXML = [self callURL:@"https://fireeagle.yahooapis.com/api/0.1/user" withArguments:nil usePOST:FALSE];
	if(!locationXML)
		return nil;
	
	id locationData = [FEXMLParser parseString:locationXML];
	
	if([locationData isKindOfClass:[FELocationHierarchy class]])
	{
		return locationData;
	}
	else if([locationData isKindOfClass:[NSError class]])
	{
		[self handleError:locationData];
	}
	else
	{
		[self handleError:[NSError errorWithDomain:@"FEClientErrorDomain" code:1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				@"Failed to parse Fire Eagle location XML", NSLocalizedDescriptionKey,
				locationXML, @"FELocationXML"]]];
	}
	
	return nil;
}

/**
 * Synchronous method to retrieve possible meanings of an address
 */
- (NSDictionary*)locationLookupFromAddress:(NSString*)address
{
	return [self locationLookup:[NSDictionary dictionaryWithObject:address forKey:FELocationAddressKey]];
}

/**
 * Synchronous method to retrieve possible meanings of a location
 */
- (NSDictionary*)locationLookup:(NSDictionary*)location
{
	if(![self isAuthorised])
	{
		[self handleError:[NSError 
			errorWithDomain:@"FEClientErrorDomain" 
			code:21 // Fire Eagle error code for no oauth token
			//TODO: use self.applicationName in the error message below
			userInfo:[NSDictionary dictionaryWithObject:@"You must allow this application access to your Fire Eagle data before you can look up a location" forKey:NSLocalizedDescriptionKey]]];
		return nil;
	}

	NSString *lookupXML = [self callURL:@"https://fireeagle.yahooapis.com/api/0.1/lookup" withArguments:location usePOST:FALSE];
	if(!lookupXML)
		return nil;
	
	id lookupData = [FEXMLParser parseString:lookupXML];
	
	if([lookupData isKindOfClass:[NSDictionary class]])
	{
		return lookupData;
	}
	else if([lookupData isKindOfClass:[NSError class]])
	{
		[self handleError:lookupData];
	}
	else
	{
		[self handleError:[NSError errorWithDomain:@"FEClientErrorDomain" code:1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
				@"Failed to parse Fire Eagle look up XML", NSLocalizedDescriptionKey,
				lookupXML, @"FELocationXML"]]];
	}
	
	return nil;
}

/**
 * Synchronous method to set the user's location
 */
- (BOOL)setUserLocationToAddress:(NSString*)newAddress
{
	return [self setUserLocation:[NSDictionary dictionaryWithObject:newAddress forKey:FELocationAddressKey]];
}

/**
 * Synchronous method to set the user's location
 */
- (BOOL)setUserLocation:(NSDictionary*)newLocation
{
	if(![self isAuthorised])
	{
		[self handleError:[NSError 
			errorWithDomain:@"FEClientErrorDomain" 
			code:21 // Fire Eagle error code for no oauth token
			//TODO: Use self.applicationName in the error message below
			userInfo:[NSDictionary dictionaryWithObject:@"You must allow this application access to your Fire Eagle data before you can update your location" forKey:NSLocalizedDescriptionKey]]];
		return FALSE;
	}

	NSString *result = [self callURL:@"https://fireeagle.yahooapis.com/api/0.1/update" withArguments:newLocation usePOST:TRUE];
	return result ? TRUE : FALSE;
}



// ===========================================================================
// =========================== GUI CONTROL METHODS ===========================
// ===========================================================================

- (void)clarifyAndSetUserLocationThreadMain:(NSString*)newLocation
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self incrementWorking];

	if(!clarificationController)
	{
		clarificationController = [[[FEClarificationController alloc] init] retain];
		clarificationController.client = self;
		[NSBundle loadNibNamed:@"FEClarification" owner:clarificationController];
	}
	
	NSDictionary *locationData = [self locationLookupFromAddress:newLocation];
	[clarificationController performSelectorOnMainThread:@selector(clarifyAndSetUserLocation:) withObject:locationData waitUntilDone:FALSE];
	
	[self decrementWorking];
	[pool release];
}

- (void)clarifyAndSetUserLocation:(NSString*)newLocation
{	
	[NSThread 
		detachNewThreadSelector:@selector(clarifyAndSetUserLocationThreadMain:) 
		toTarget:self 
		withObject:newLocation];
}




// ===========================================================================
// ========================== WORKER THREAD TRACKING =========================
// ===========================================================================

- (BOOL)isWorking
{
	return (working > 0);
}

- (void)incrementWorking
{
	if(working == 0)
	{
		[self willChangeValueForKey:@"working"];
		working = 1;
		[self didChangeValueForKey:@"working"];
	}
	else
		working++;
}

- (void)decrementWorking
{
	if(working == 1)
	{
		[self willChangeValueForKey:@"working"];
		working = 0;
		[self didChangeValueForKey:@"working"];
	}
	else
		working--;
}



// ===========================================================================
// ============================ KEY CHAIN METHODS ============================
// ===========================================================================

- (void)storeAccessTokenInKeychain
{
	if(!self.useKeychain)
		return;

	//return;	//TEMP: Disabled for repeated auth testing

	// Create attributes array
	SecKeychainAttribute attributes[3];
	
	// Set the account name (uses the application's consumer key)
    attributes[0].tag = kSecAccountItemAttr;
    attributes[0].data = (void*)[consumerKey UTF8String];
    attributes[0].length = [consumerKey length];
    
	// Set the description
	NSString *itemDescription = @"Fire Eagle access token";
    attributes[1].tag = kSecDescriptionItemAttr;
    attributes[1].data = (void*)[itemDescription UTF8String];
    attributes[1].length = [itemDescription length];
	
	// Label the item
	NSString *itemLabel = [NSString stringWithFormat:@"Fire Eagle token for %@", consumerKey];
	attributes[2].tag = kSecLabelItemAttr;
    attributes[2].data = (void*)[itemLabel UTF8String];
    attributes[2].length = [itemLabel length];

	// Create list from attributes array
    SecKeychainAttributeList list;
    list.count = 3;
    list.attr = attributes;

	// Store the password
	NSString *password = [NSString stringWithFormat:@"%@-%@", accessToken, accessTokenSecret ];
    SecKeychainItemCreateFromContent(kSecGenericPasswordItemClass, &list, [password length], [password UTF8String], NULL,NULL,NULL);
}

- (void)removeAccessTokenFromKeychain
{
}

- (void)retrieveAccessTokenFromKeychain
{
    SecKeychainSearchRef search;
    SecKeychainItemRef item;
    SecKeychainAttributeList list;
    SecKeychainAttribute attributes[3];
    OSErr result;

	attributes[0].tag = kSecAccountItemAttr;
    attributes[0].data = (void*)[consumerKey UTF8String];
    attributes[0].length = [consumerKey length];
    
	NSString *itemDescription = @"Fire Eagle access token";
    attributes[1].tag = kSecDescriptionItemAttr;
    attributes[1].data = (void*)[itemDescription UTF8String];
    attributes[1].length = [itemDescription length];
	
	NSString *itemLabel = [NSString stringWithFormat:@"Fire Eagle token for %@", consumerKey];
	attributes[2].tag = kSecLabelItemAttr;
    attributes[2].data = (void*)[itemLabel UTF8String];
    attributes[2].length = [itemLabel length];

    list.count = 3;
    list.attr = (SecKeychainAttribute*)&attributes;

    result = SecKeychainSearchCreateFromAttributes(NULL, kSecGenericPasswordItemClass, &list, &search);

    if(result != noErr)
		return;
	
    if (SecKeychainSearchCopyNext(search, &item) == noErr) 
	{
		UInt32 length;
		char *password;
		OSStatus status;
											 
		status = SecKeychainItemCopyContent(item, NULL, NULL, &length, (void **)&password);
		
		if (status == noErr) 
		{
			if (password != NULL) 
			{
				char passwordBuffer[length+1];
				strncpy(passwordBuffer, password, length);
				passwordBuffer[length] = '\0';
				
				NSArray *passwordParts = [[NSString stringWithUTF8String:passwordBuffer] componentsSeparatedByString:@"-"];
				
				[self willChangeValueForKey:@"authorised"];
				[accessToken release], accessToken = [[passwordParts objectAtIndex:0] retain];
				[accessTokenSecret release], accessTokenSecret = [[passwordParts objectAtIndex:1] retain];
				[self didChangeValueForKey:@"authorised"];
				
				if(delegate && [delegate respondsToSelector:@selector(fireEagleClientWasAuthorised:)])
					[delegate performSelector:@selector(fireEagleClientWasAuthorised:) withObject:self];
			}

			SecKeychainItemFreeContent(NULL, password);
		}

		CFRelease(item);
		CFRelease (search);
	}

}

@end
