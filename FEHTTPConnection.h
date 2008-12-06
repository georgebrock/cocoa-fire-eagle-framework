//
//  FEHTTPConnection.h
//  FireEagleClient
//
//  Created by George on 21/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//
//	This class is heavily based on the SimpleHTTPConnection class:
//		Created by Jürgen on 19.09.06.
//		Copyright 2006 Cultured Code.
//		License: Creative Commons Attribution 2.5 License
//           http://creativecommons.org/licenses/by/2.5/

#import <Cocoa/Cocoa.h>


@interface FEHTTPConnection : NSObject {
    NSFileHandle *fileHandle;
    id delegate;
    NSString *address;  // client IP address

    CFHTTPMessageRef message;
    BOOL isMessageComplete;
}

- (id)initWithFileHandle:(NSFileHandle *)fh delegate:(id)dl;
- (NSFileHandle *)fileHandle;

- (void)setAddress:(NSString *)value;
- (NSString *)address;

@end