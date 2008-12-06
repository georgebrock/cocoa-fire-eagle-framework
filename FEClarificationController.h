//
//  FEClarificationController.h
//  FireEagleClient
//
//  Created by George on 25/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class FEClient;

@interface FEClarificationController : NSObject 
{
	FEClient *client;
	IBOutlet NSPanel *clarificationPanel;
	IBOutlet NSArrayController *clarificationArrayController;
}

@property(retain, readwrite) FEClient *client;

- (void)clarifyAndSetUserLocation:(NSDictionary*)locationData;
- (IBAction)setLocationFromClarificationList:(id)sender;
- (IBAction)cancelClarification:(id)sender;

@end
