//
//  RakamURLConnection.h
//  Rakam
//
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RakamURLConnection : NSObject <NSURLConnectionDelegate,NSURLConnectionDataDelegate>

+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))handler;

@end