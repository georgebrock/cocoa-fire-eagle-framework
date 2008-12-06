//
//  FEAuthController.m
//  FireEagleClient
//
//  Created by George on 25/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "FEAuthController.h"
#import "FEClient.h"

#define FEHTTPPort 3473

@interface FEClient (Private)
- (BOOL)requestAccessToken;
@end

@implementation FEAuthController

@synthesize client, customProtocol;

- (void)awakeFromNib
{
/*
	webServer = [[[FEHTTPServer alloc] initWithTCPPort:FEHTTPPort delegate:self] retain];

	[[NSNotificationCenter defaultCenter] addObserver:self
		   selector:@selector(webViewProgressUpdate:)
			   name:WebViewProgressEstimateChangedNotification
			 object:webView];
*/
//*			 
	// Create a unique protocol name for this app
	NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
	self.customProtocol = [NSString stringWithFormat:@"x-%@", [[bundleID lowercaseString] stringByReplacingOccurrencesOfString:@"." withString:@"-"]];
	NSLog(@"Custom protocol is: %@", self.customProtocol);
	
	// Register with Launch Services as a handler for this protocol
	OSStatus result = LSSetDefaultHandlerForURLScheme((CFStringRef)self.customProtocol, (CFStringRef)bundleID);
	//TODO: If result is bad, handle the error
	
	// Set the appropriate callback for when a URL is loaded
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(getUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
//*/
}

//*
- (void)getUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSLog(@"A custom URL was spotted: %@", url);
}
//*/

- (void)dealloc
{
	[webServer release], webServer = nil;
	[super dealloc];
}

- (void)beginAuthentication
{
	NSURL *loadingURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/loading", FEHTTPPort]];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:loadingURL]];

	// Load the authentication interface
	NSWindow *keyWindow = [NSApp keyWindow];
	if(keyWindow)
		[NSApp beginSheet:authPanel modalForWindow:keyWindow modalDelegate:self didEndSelector:NULL contextInfo:nil];
	else
		[authPanel makeKeyAndOrderFront:self];
}

- (void)authenticateWithToken:(NSString*)requestToken
{
	// Send the user to the authorisation page
	//NSString *callbackURL = [NSString stringWithFormat:@"http://localhost:%d/auth_complete", FEHTTPPort];
	NSString *callbackURL = [NSString stringWithFormat:@"%@://fireeagle/auth_complete", self.customProtocol];
	NSString *escapedCallbackURL = (NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)callbackURL, NULL, (CFStringRef)@"&=:/,", kCFStringEncodingASCII);
	NSURL *authURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://fireeagle.yahoo.net/oauth/authorize?oauth_token=%@&oauth_callback=%@", requestToken, escapedCallbackURL]];
	//[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:authURL]];
	[[NSWorkspace sharedWorkspace] openURL:authURL];
}

- (void)authenticationError:(NSString*)errorMessage
{
	NSString *escapedErrorMessage = (NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)errorMessage, NULL, (CFStringRef)@"&=:/,", kCFStringEncodingASCII);
	NSURL *errorURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d/error?message=%@", FEHTTPPort, escapedErrorMessage]];
	[[webView mainFrame] loadRequest:[NSURLRequest requestWithURL:errorURL]];	
}

- (IBAction)cancelAuthentication:(id)sender
{
    [authPanel orderOut:nil];
    [NSApp endSheet:authPanel];
}

- (void)webViewProgressUpdate:(NSNotification*)notification
{
	[webViewProgressBar setDoubleValue:[webView estimatedProgress]];
}

- (BOOL)isInterfaceVisible
{
	return [authPanel isVisible];
}

// ===========================================================================
// ======================= WEB SERVER DELEGATE METHODS =======================
// ===========================================================================

- (void)processURL:(NSURL *)path connection:(FEHTTPConnection *)connection
{	
	// Handle auth_complete URL:
	// We are redirected to this address when the user has chosen the level of Fire Eagle access
	if([[path path] isEqualToString:@"/auth_complete"])
	{
		//[webServer replyWithData:[@"<html><head><title>Fire Eagle</title></head><body><h1>Requesting access token...</h1></body></html>" dataUsingEncoding:NSUTF8StringEncoding] MIMEType:@"text/html"];
		BOOL result = [client requestAccessToken];
		if(result)
			[self cancelAuthentication:nil];
		return;
	}
	
	if([[path path] isEqualToString:@"/loading"])
	{
		NSString *loadingFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"loading" ofType:@"html"];
		NSData *loadingPage = [NSData dataWithContentsOfFile:loadingFilePath];
		[webServer replyWithData:loadingPage MIMEType:@"text/html"];
		return;
	}
	
	if([[path path] isEqualToString:@"/loading.gif"])
	{
		NSString *loadingGIFPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"loading" ofType:@"gif"];
		NSData *loadingGIF = [NSData dataWithContentsOfFile:loadingGIFPath];
		[webServer replyWithData:loadingGIF MIMEType:@"image/gif"];
		return;
	}
	
	if([[path path] isEqualToString:@"/error"])
	{
		NSString *errorFilePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"error" ofType:@"html"];
		NSData *errorPage = [NSData dataWithContentsOfFile:errorFilePath];
		[webServer replyWithData:errorPage MIMEType:@"text/html"];
		return;
	}
	
	//TODO: Add a 404 response, more for completeness more than anything else
}

- (void)stopProcessing
{
}

@end
