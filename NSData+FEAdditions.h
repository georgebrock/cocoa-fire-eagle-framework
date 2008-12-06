//
//  NSData+FEAdditions.h
//  FireEagleClient
//
//  Created by George on 01/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSData (FEAdditions)

- (NSString *) encodeBase64;
- (NSString *) encodeBase64WithNewlines: (BOOL) encodeWithNewlines;

@end