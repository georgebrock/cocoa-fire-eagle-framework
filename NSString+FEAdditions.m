//
//  NSString+FEAdditions.m
//  FireEagleClient
//
//  Created by George on 30/05/2008.
//  Copyright 2008 George Brocklehurst. All rights reserved.
//

#import "NSString+FEAdditions.h"
#import "NSData+FEAdditions.h"
#include <openssl/md5.h>
#include <openssl/sha.h>


@implementation NSString (FEAdditions)

- (NSString*)MD5Hash
{
	NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
	if(data) 
	{
		unsigned char *digest = MD5([data bytes], [data length], NULL);
		return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
			digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]];
	}
	
	return nil;
}

- (NSString*)SHA1Hash
{
	NSData *data = [self dataUsingEncoding:[NSString defaultCStringEncoding]];
	if(data) 
	{
		unsigned char *digest = SHA1([data bytes], [data length], NULL);
		
	//	NSLog(@"Digest of \"%@\" is \"%s\"", self, digest);
		
		return [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
			digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
			digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15],
			digest[16], digest[17], digest[18], digest[19]];
	}
	
	return nil;
}

- (NSString*)SHA1HMACWithKey:(NSString*)key
{
	// Commonly used variables
	int i;
	int blockSize = 64;

	// Format the key
	NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
	unsigned char cKey[blockSize];	
	if([key length] > blockSize)
	{
		unsigned char *keyDigest = SHA1([keyData bytes], [keyData length], NULL);
		for(i = 0; i < blockSize; i++)
			cKey[i] = (i < 20 ? keyDigest[i] : (char)0);
	}
	else
	{
		char *keyBytes = (char*)[keyData bytes];
		for(i = 0; i < blockSize; i++)
			cKey[i] = (i < [key length] ? keyBytes[i] : (char)0);
	}
	
	// Create the pad arrays
	unsigned char ipad[blockSize];
	unsigned char opad[blockSize];
	for(i = 0; i < blockSize; i++)
	{
		ipad[i] = (char)0x36 ^ cKey[i];
		opad[i] = (char)0x5c ^ cKey[i];
	}

	// Create string for inner digest
	NSData *myData = [self dataUsingEncoding:NSUTF8StringEncoding];
	char *myBytes = (char*)[myData bytes];
	int innerCStringLength = blockSize + [myData length];
	unsigned char innerCString[innerCStringLength];
	for(i = 0; i < innerCStringLength; i++)
		innerCString[i] = (i < blockSize ? ipad[i] : myBytes[i-blockSize]);
	
	// Get inner digest
	unsigned char *innerDigest = SHA1(innerCString, innerCStringLength, NULL);
	
	// Create string for outer digest
	int outerCStringLength = blockSize + 20;
	unsigned char outerCString[outerCStringLength];
	for(i = 0; i < outerCStringLength; i++)
		outerCString[i] = (i < blockSize ? opad[i] : innerDigest[i-blockSize]);

	// Get outer digest
	unsigned char *outerDigest = SHA1(outerCString, outerCStringLength, NULL); //[outerData bytes], [outerData length]
	
	// Return base64 encoded result
	NSString *base64 = [[NSData dataWithBytes:outerDigest length:20] encodeBase64WithNewlines:FALSE];	
	return base64;
}


- (NSDictionary*)queryStringComponents
{
	NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
	NSScanner *scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"&="]];
	while(![scanner isAtEnd])
	{
		NSString *key, *value;
		[scanner scanUpToString:@"=" intoString:&key];
		[scanner scanUpToString:@"&" intoString:&value];
		[dict 
			setObject:[value stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
			forKey:key];
	}
	
	return [dict autorelease];
}

@end