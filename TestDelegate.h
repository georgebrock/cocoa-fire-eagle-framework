//
//  TestDelegate.h
//  FireEagleClient
//
//  Created by George on 07/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class FEClient;

@interface TestDelegate : NSObject 
{
	IBOutlet FEClient *fireEagle;
	
	IBOutlet NSWindow *mainWindow;
	IBOutlet NSTextField *inputField;
	IBOutlet NSTextView *outputField;
	
	IBOutlet NSObjectController *currentLocationController;
}


- (IBAction)authorise:(id)sender;
- (IBAction)lookup:(id)sender;
- (IBAction)setLocation:(id)sender;
- (IBAction)getLocation:(id)sender;

@end
