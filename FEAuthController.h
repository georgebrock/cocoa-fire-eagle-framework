//
//  FEAuthController.h
//  FireEagleClient
//
//  Created by George on 25/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Webkit/Webkit.h>
#import "FEHTTPServer.h"
@class FEClient;

@interface FEAuthController : NSObject 
{
	FEClient *client;
	FEHTTPServer *webServer;
	
	NSString *customProtocol;
	
	IBOutlet NSPanel *authPanel;
	IBOutlet WebView *webView;
	IBOutlet NSProgressIndicator *webViewProgressBar;
}

@property(retain, readwrite) FEClient *client;
@property(retain, readwrite) NSString *customProtocol;

- (void)beginAuthentication;
- (void)authenticateWithToken:(NSString*)requestToken;
- (void)authenticationError:(NSString*)errorMessage;

- (BOOL)isInterfaceVisible;

- (IBAction)cancelAuthentication:(id)sender;

@end
