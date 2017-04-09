//
//  SessionTests.m
//  SessionTests
//
//  Created by Curtis on 9/24/14.
//  Copyright (c) 2014 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "Rakam.h"
#import "Rakam+Test.h"
#import "BaseTestCase.h"
#import "RakamConstants.h"
#import "RakamUtils.h"

@interface SetupTests : BaseTestCase

@end

@implementation SetupTests { }

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testApiKeySet {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    XCTAssertEqual(self.amplitude.apiKey, apiKey);
}

- (void)testDeviceIdSet {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [self.amplitude flushQueue];
    XCTAssertNotNil([self.amplitude deviceId]);
    XCTAssertEqual([self.amplitude deviceId].length, 36);
    XCTAssertEqualObjects([self.amplitude deviceId], [[[UIDevice currentDevice] identifierForVendor] UUIDString]);
}

- (void)testUserIdNotSet {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [self.amplitude flushQueue];
    XCTAssertNil([self.amplitude userId]);
}

- (void)testUserIdSet {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey userId:userId];
    [self.amplitude flushQueue];
    XCTAssertEqualObjects([self.amplitude userId], userId);
}

- (void)testInitializedSet {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    XCTAssert([self.amplitude initialized]);
}

- (void)testOptOut {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];

    [self.amplitude setOptOut:YES];
    [self.amplitude logEvent:@"Opted Out"];
    [self.amplitude flushQueue];

    XCTAssert(self.amplitude.optOut == YES);
    XCTAssert(![[self.amplitude getLastEvent][@"collection"] isEqualToString:@"Opted Out"]);

    [self.amplitude setOptOut:NO];
    [self.amplitude logEvent:@"Opted In"];
    [self.amplitude flushQueue];

    XCTAssert(self.amplitude.optOut == NO);
    XCTAssert([[self.amplitude getLastEvent][@"collection"] isEqualToString:@"Opted In"]);
}

- (void)testUserPropertiesSet {
    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    XCTAssertEqual([dbHelper getEventCount], 0);

    NSDictionary *properties = @{
         @"shoeSize": @10,
         @"hatSize":  @5.125,
         @"name": @"John"
    };

    [self.amplitude setUserProperties:properties];
    [self.amplitude flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    XCTAssertEqual([dbHelper getTotalEventCount], 1);

    NSDictionary *expected = [NSDictionary dictionaryWithObject:properties forKey:RKM_OP_SET];

    NSDictionary *event = [self.amplitude getLastIdentify];
    XCTAssertEqualObjects([event objectForKey:@"collection"], IDENTIFY_EVENT);
    XCTAssertTrue([self key:[event objectForKey:@"properties"] containsInDictionary:expected]);
}

-(BOOL)key:(NSDictionary *)main containsInDictionary:(NSDictionary *)Dictionary
{
    for (NSString *keyStr in Dictionary) {
        if(![[Dictionary objectForKey:keyStr] isEqual:[main objectForKey:keyStr]]) {
            return false;
        }
    }
    return true;
}

- (void)testSetDeviceId {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];

    [self.amplitude initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [self.amplitude flushQueue];
    NSString *generatedDeviceId = [self.amplitude getDeviceId];
    XCTAssertNotNil(generatedDeviceId);
    XCTAssertEqual(generatedDeviceId.length, 36);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    // test setting invalid device ids
    [self.amplitude setDeviceId:nil];
    [self.amplitude flushQueue];
    XCTAssertEqualObjects([self.amplitude getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    id dict = [NSDictionary dictionary];
    [self.amplitude setDeviceId:dict];
    [self.amplitude flushQueue];
    XCTAssertEqualObjects([self.amplitude getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    [self.amplitude setDeviceId:@"e3f5536a141811db40efd6400f1d0a4e"];
    [self.amplitude flushQueue];
    XCTAssertEqualObjects([self.amplitude getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    [self.amplitude setDeviceId:@"04bab7ee75b9a58d39b8dc54e8851084"];
    [self.amplitude flushQueue];
    XCTAssertEqualObjects([self.amplitude getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    NSString *validDeviceId = [RakamUtils generateUUID];
    [self.amplitude setDeviceId:validDeviceId];
    [self.amplitude flushQueue];
    XCTAssertEqualObjects([self.amplitude getDeviceId], validDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], validDeviceId);
}

@end
