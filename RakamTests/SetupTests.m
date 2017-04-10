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
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    XCTAssertEqual(self.rakam.apiKey, apiKey);
}

- (void)testDeviceIdSet {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [self.rakam flushQueue];
    XCTAssertNotNil([self.rakam deviceId]);
    XCTAssertEqual([self.rakam deviceId].length, 36);
    XCTAssertEqualObjects([self.rakam deviceId], [[[UIDevice currentDevice] identifierForVendor] UUIDString]);
}

- (void)testUserIdNotSet {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [self.rakam flushQueue];
    XCTAssertNil([self.rakam userId]);
}

- (void)testUserIdSet {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey userId:userId];
    [self.rakam flushQueue];
    XCTAssertEqualObjects([self.rakam userId], userId);
}

- (void)testInitializedSet {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    XCTAssert([self.rakam initialized]);
}

- (void)testOptOut {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];

    [self.rakam setOptOut:YES];
    [self.rakam logEvent:@"Opted Out"];
    [self.rakam flushQueue];

    XCTAssert(self.rakam.optOut == YES);
    XCTAssert(![[self.rakam getLastEvent][@"collection"] isEqualToString:@"Opted Out"]);

    [self.rakam setOptOut:NO];
    [self.rakam logEvent:@"Opted In"];
    [self.rakam flushQueue];

    XCTAssert(self.rakam.optOut == NO);
    XCTAssert([[self.rakam getLastEvent][@"collection"] isEqualToString:@"Opted In"]);
}

- (void)testUserPropertiesSet {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    XCTAssertEqual([dbHelper getEventCount], 0);

    NSDictionary *properties = @{
         @"shoeSize": @10,
         @"hatSize":  @5.125,
         @"name": @"John"
    };

    [self.rakam setUserProperties:properties];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    XCTAssertEqual([dbHelper getTotalEventCount], 1);

    NSDictionary *expected = [NSDictionary dictionaryWithObject:properties forKey:RKM_OP_SET];

    NSDictionary *event = [self.rakam getLastIdentify];
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

    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [self.rakam flushQueue];
    NSString *generatedDeviceId = [self.rakam getDeviceId];
    XCTAssertNotNil(generatedDeviceId);
    XCTAssertEqual(generatedDeviceId.length, 36);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    // test setting invalid device ids
    [self.rakam setDeviceId:nil];
    [self.rakam flushQueue];
    XCTAssertEqualObjects([self.rakam getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    id dict = [NSDictionary dictionary];
    [self.rakam setDeviceId:dict];
    [self.rakam flushQueue];
    XCTAssertEqualObjects([self.rakam getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    [self.rakam setDeviceId:@"e3f5536a141811db40efd6400f1d0a4e"];
    [self.rakam flushQueue];
    XCTAssertEqualObjects([self.rakam getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    [self.rakam setDeviceId:@"04bab7ee75b9a58d39b8dc54e8851084"];
    [self.rakam flushQueue];
    XCTAssertEqualObjects([self.rakam getDeviceId], generatedDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], generatedDeviceId);

    NSString *validDeviceId = [RakamUtils generateUUID];
    [self.rakam setDeviceId:validDeviceId];
    [self.rakam flushQueue];
    XCTAssertEqualObjects([self.rakam getDeviceId], validDeviceId);
    XCTAssertEqualObjects([dbHelper getValue:@"device_id"], validDeviceId);
}

@end
