//
//  NSString+FEAdditions.h
//  FireEagleClient
//
//  Created by George on 30/05/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSString (FEAdditions) 

- (NSString*)MD5Hash;
- (NSString*)SHA1Hash;
- (NSString*)SHA1HMACWithKey:(NSString*)key;

- (NSDictionary*)queryStringComponents;

@end
