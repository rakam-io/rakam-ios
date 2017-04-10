//
//  BaseTestCase.h
//  Rakam
//
//  Created by Allan on 3/11/15.
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "RakamDatabaseHelper.h"

extern NSString *const apiKey;
extern NSString *const userId;

@interface BaseTestCase : XCTestCase

@property (nonatomic, strong) Rakam *rakam;
@property (nonatomic, strong) RakamDatabaseHelper *databaseHelper;

- (BOOL) archive:(id)rootObject toFile:(NSString *)path;
- (id) unarchive:(NSString *)path;

@end
