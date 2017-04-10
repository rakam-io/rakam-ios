//
//  BaseTestCase.m
//  Rakam
//
//  Created by Allan on 3/11/15.
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "Rakam.h"
#import "Rakam+Test.h"
#import "BaseTestCase.h"
#import "RakamARCMacros.h"
#import "RakamDatabaseHelper.h"

NSString *const apiKey = @"000000";
NSString *const userId = @"userId";

@implementation BaseTestCase {
    id _archivedObj;
}

- (void)setUp {
    [super setUp];
    self.rakam = [Rakam alloc];
    self.databaseHelper = [RakamDatabaseHelper getDatabaseHelper];
    XCTAssertTrue([self.databaseHelper resetDB:NO]);

    [self.rakam init];
    self.rakam.sslPinningEnabled = NO;
}

- (void)tearDown {
    // Ensure all background operations are done
    [self.rakam flushQueueWithQueue:self.rakam.initializerQueue];
    [self.rakam flushQueue];
    SAFE_ARC_RELEASE(_rakam);
    SAFE_ARC_RELEASE(_databaseHelper);
    [super tearDown];
}

- (BOOL)archive:(id)rootObject toFile:(NSString *)path {
    _archivedObj = rootObject;
    return YES;
}

- (id)unarchive:(NSString *)path {
    return _archivedObj;
}

@end
