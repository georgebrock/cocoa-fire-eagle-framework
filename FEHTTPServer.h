//
//  FEHTTPServer.h
//  FireEagleClient
//
//  Created by George on 21/06/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//
//	This class is heavily based on the SimpleHTTPServer class:
//		Created by Jürgen on 19.09.06.
//		Copyright 2006 Cultured Code.
//		License: Creative Commons Attribution 2.5 License
//           http://creativecommons.org/licenses/by/2.5/

#import <Cocoa/Cocoa.h>

@class FEHTTPConnection;

@interface FEHTTPServer : NSObject 
{
    unsigned port;
	id delegate;

    NSSocketPort *socketPort;
    NSFileHandle *fileHandle;
    NSMutableArray *connections;
    NSMutableArray *requests;    
    NSDictionary *currentRequest;
}

- (id)initWithTCPPort:(unsigned)po delegate:(id)dl;

- (NSArray *)connections;
- (NSArray *)requests;

- (void)closeConnection:(FEHTTPConnection *)connection;
- (void)newRequestWithURL:(NSURL *)url connection:(FEHTTPConnection *)connection;

// Request currently being processed
// Note: this need not be the most recently received request
- (NSDictionary *)currentRequest;

- (void)replyWithStatusCode:(int)code headers:(NSDictionary *)headers body:(NSData *)body;
- (void)replyWithData:(NSData *)data MIMEType:(NSString *)type;
- (void)replyWithStatusCode:(int)code message:(NSString *)message;

@end
