//
//  RakamTests.m
//  Rakam
//
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "Rakam.h"
#import "RakamConstants.h"
#import "Rakam+Test.h"
#import "BaseTestCase.h"
#import "RakamDeviceInfo.h"
#import "RakamARCMacros.h"
#import "RakamUtils.h"

// expose private methods for unit testing
@interface Rakam (Tests)
- (NSDictionary *)mergeEventsAndIdentifys:(NSMutableArray *)events identifys:(NSMutableArray *)identifys numEvents:(long)numEvents;

- (id)truncate:(id)obj;

- (long long)getNextSequenceNumber;
@end

@interface RakamTests : BaseTestCase

@end

@implementation RakamTests {
    id _connectionMock;
    int _connectionCallCount;
}

- (void)setUp {
    [super setUp];
    _connectionMock = [OCMockObject mockForClass:NSURLConnection.class];
    _connectionCallCount = 0;
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : apiKey];
}

- (void)tearDown {
    [_connectionMock stopMocking];
}

- (void)setupAsyncResponse:(id)connectionMock response:(NSMutableDictionary *)serverResponse {
    [[[connectionMock expect] andDo:^(NSInvocation *invocation) {
        _connectionCallCount++;
        void (^handler)(NSURLResponse *, NSData *, NSError *);
        [invocation getArgument:&handler atIndex:4];
        handler(serverResponse[@"response"], serverResponse[@"data"], serverResponse[@"error"]);
    }] sendAsynchronousRequest:OCMOCK_ANY queue:OCMOCK_ANY completionHandler:OCMOCK_ANY];
}

- (void)testInstanceWithName {
    Rakam *a = [Rakam instance];
    Rakam *b = [Rakam instanceWithName:@""];
    Rakam *c = [Rakam instanceWithName:nil];
    Rakam *e = [Rakam instanceWithName:kRKMDefaultInstance];
    Rakam *f = [Rakam instanceWithName:@"app1"];
    Rakam *g = [Rakam instanceWithName:@"app2"];

    XCTAssertEqual(a, b);
    XCTAssertEqual(b, c);
    XCTAssertEqual(c, e);
    XCTAssertEqual(e, a);
    XCTAssertEqual(e, [Rakam instance]);
    XCTAssertNotEqual(e, f);
    XCTAssertEqual(f, [Rakam instanceWithName:@"app1"]);
    XCTAssertNotEqual(f, g);
    XCTAssertEqual(g, [Rakam instanceWithName:@"app2"]);
}

- (void)testInitWithInstanceName {
    Rakam *a = [Rakam instanceWithName:@"APP1"];
    [a flushQueueWithQueue:a.initializerQueue];
    XCTAssertEqualObjects(a.instanceName, @"app1");
    XCTAssertTrue([a.propertyListPath rangeOfString:@"io.rakam.plist_app1"].location != NSNotFound);

    Rakam *b = [Rakam instanceWithName:[kRKMDefaultInstance uppercaseString]];
    [b flushQueueWithQueue:b.initializerQueue];
    XCTAssertEqualObjects(b.instanceName, kRKMDefaultInstance);
    XCTAssertTrue([b.propertyListPath rangeOfString:@"io.rakam.plist"].location != NSNotFound);
    XCTAssertTrue([b.propertyListPath rangeOfString:@"io.rakam.plist_"].location == NSNotFound);
}

- (void)testInitializeLoadNilUserIdFromEventData {
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nil);
    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];
    NSDictionary *event = [self.rakam getLastEvent];
    XCTAssertEqual([((NSDictionary *) [event objectForKey:@"properties"]) objectForKey:@"_user"], nil);
}

- (void)testSeparateInstancesLogEventsSeparate {
    NSString *newInstance1 = @"newApp1";
    NSString *newApiKey1 = @"1234567890";
    NSString *newInstance2 = @"newApp2";
    NSString *newApiKey2 = @"0987654321";

    RakamDatabaseHelper *oldDbHelper = [RakamDatabaseHelper getDatabaseHelper];
    RakamDatabaseHelper *newDBHelper1 = [RakamDatabaseHelper getDatabaseHelper:newInstance1];
    RakamDatabaseHelper *newDBHelper2 = [RakamDatabaseHelper getDatabaseHelper:newInstance2];

    // reset databases
    [oldDbHelper resetDB:NO];
    [newDBHelper1 resetDB:NO];
    [newDBHelper2 resetDB:NO];

    // setup existing database file, init default instance
    [oldDbHelper insertOrReplaceKeyLongValue:@"sequence_number" value:[NSNumber numberWithLongLong:1000]];
    [oldDbHelper addEvent:@"{\"collection\":\"oldEvent\"}"];
    [oldDbHelper addIdentify:@"{\"collection\":\"$identify\"}"];
    [oldDbHelper addIdentify:@"{\"collection\":\"$identify\"}"];

    [[Rakam instance] setDeviceId:@"oldDeviceId"];
    [[Rakam instance] flushQueue];
    XCTAssertEqualObjects([oldDbHelper getValue:@"device_id"], @"oldDeviceId");
    XCTAssertEqualObjects([[Rakam instance] getDeviceId], @"oldDeviceId");
    XCTAssertEqual([[Rakam instance] getNextSequenceNumber], 1001);

    XCTAssertNil([newDBHelper1 getValue:@"device_id"]);
    XCTAssertNil([newDBHelper2 getValue:@"device_id"]);
    XCTAssertEqualObjects([oldDbHelper getLongValue:@"sequence_number"], [NSNumber numberWithLongLong:1001]);
    XCTAssertNil([newDBHelper1 getLongValue:@"sequence_number"]);
    XCTAssertNil([newDBHelper2 getLongValue:@"sequence_number"]);

    // init first new app and verify separate database
    [[Rakam instanceWithName:newInstance1] initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : newApiKey1];
    [[Rakam instanceWithName:newInstance1] flushQueue];
    XCTAssertNotEqualObjects([[Rakam instanceWithName:newInstance1] getDeviceId], @"oldDeviceId");
    XCTAssertEqualObjects([[Rakam instanceWithName:newInstance1] getDeviceId], [newDBHelper1 getValue:@"device_id"]);
    XCTAssertEqual([[Rakam instanceWithName:newInstance1] getNextSequenceNumber], 1);
    XCTAssertEqual([newDBHelper1 getEventCount], 0);
    XCTAssertEqual([newDBHelper1 getIdentifyCount], 0);

    // init second new app and verify separate database
    [[Rakam instanceWithName:newInstance2] initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : newApiKey2];
    [[Rakam instanceWithName:newInstance2] flushQueue];
    XCTAssertNotEqualObjects([[Rakam instanceWithName:newInstance2] getDeviceId], @"oldDeviceId");
    XCTAssertEqualObjects([[Rakam instanceWithName:newInstance2] getDeviceId], [newDBHelper2 getValue:@"device_id"]);
    XCTAssertEqual([[Rakam instanceWithName:newInstance2] getNextSequenceNumber], 1);
    XCTAssertEqual([newDBHelper2 getEventCount], 0);
    XCTAssertEqual([newDBHelper2 getIdentifyCount], 0);

    // verify old database still intact
    XCTAssertEqualObjects([oldDbHelper getValue:@"device_id"], @"oldDeviceId");
    XCTAssertEqualObjects([oldDbHelper getLongValue:@"sequence_number"], [NSNumber numberWithLongLong:1001]);
    XCTAssertEqual([oldDbHelper getEventCount], 1);
    XCTAssertEqual([oldDbHelper getIdentifyCount], 2);

    // verify both apps can modify database independently and not affect old database
    [[Rakam instanceWithName:newInstance1] setDeviceId:@"fakeDeviceId"];
    [[Rakam instanceWithName:newInstance1] flushQueue];
    XCTAssertEqualObjects([newDBHelper1 getValue:@"device_id"], @"fakeDeviceId");
    XCTAssertNotEqualObjects([newDBHelper2 getValue:@"device_id"], @"fakeDeviceId");
    XCTAssertEqualObjects([oldDbHelper getValue:@"device_id"], @"oldDeviceId");
    [newDBHelper1 addIdentify:@"{\"collection\":\"$identify\"}"];
    XCTAssertEqual([newDBHelper1 getIdentifyCount], 1);
    XCTAssertEqual([newDBHelper2 getIdentifyCount], 0);
    XCTAssertEqual([oldDbHelper getIdentifyCount], 2);

    [[Rakam instanceWithName:newInstance2] setDeviceId:@"brandNewDeviceId"];
    [[Rakam instanceWithName:newInstance2] flushQueue];
    XCTAssertEqualObjects([newDBHelper1 getValue:@"device_id"], @"fakeDeviceId");
    XCTAssertEqualObjects([newDBHelper2 getValue:@"device_id"], @"brandNewDeviceId");
    XCTAssertEqualObjects([oldDbHelper getValue:@"device_id"], @"oldDeviceId");
    [newDBHelper2 addEvent:@"{\"collection\":\"testEvent2\"}"];
    [newDBHelper2 addEvent:@"{\"collection\":\"testEvent3\"}"];
    XCTAssertEqual([newDBHelper1 getEventCount], 0);
    XCTAssertEqual([newDBHelper2 getEventCount], 2);
    XCTAssertEqual([oldDbHelper getEventCount], 1);

    [newDBHelper1 deleteDB];
    [newDBHelper2 deleteDB];
}

- (void)testInitializeLoadUserIdFromEventData {
    NSString *instanceName = @"testInitialize";
    Rakam *client = [Rakam instanceWithName:instanceName];
    [client flushQueue];
    XCTAssertEqual([client userId], nil);

    NSString *testUserId = @"testUserId";
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper:instanceName];
    [dbHelper insertOrReplaceKeyValue:@"_user" value:testUserId];
    [client initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : apiKey];
    [client flushQueue];
    XCTAssertTrue([[client userId] isEqualToString:testUserId]);
}

- (void)testInitializeWithNilUserId {
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nil);

    NSString *nilUserId = nil;
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : apiKey userId:nilUserId];
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nilUserId);
    XCTAssertNil([[RakamDatabaseHelper getDatabaseHelper] getValue:@"_user"]);
}

- (void)testInitializeWithUserId {
    NSString *instanceName = @"testInitializeWithUserId";
    Rakam *client = [Rakam instanceWithName:instanceName];
    [client flushQueue];
    XCTAssertEqual([client userId], nil);

    NSString *testUserId = @"testUserId";
    [client initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : apiKey userId:testUserId];
    [client flushQueue];
    XCTAssertEqual([client userId], testUserId);
}

- (void)testSkipReinitialization {
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nil);

    NSString *testUserId = @"testUserId";
    [self.rakam initializeApiKey:[NSURL URLWithString:@"hhttp://127.0.0.1:9998"] : apiKey userId:testUserId];
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nil);
}

- (void)testClearUserId {
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nil);

    NSString *testUserId = @"testUserId";
    [self.rakam setUserId:testUserId];
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], testUserId);
    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];
    NSDictionary *event1 = [self.rakam getLastEvent];
    XCTAssert([[((NSDictionary *) [event1 objectForKey:@"properties"]) objectForKey:@"_user"] isEqualToString:testUserId]);

    NSString *nilUserId = nil;
    [self.rakam setUserId:nilUserId];
    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam userId], nilUserId);
    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];
    NSDictionary *event2 = [self.rakam getLastEvent];
    XCTAssertEqual([((NSDictionary *) [event2 objectForKey:@"properties"]) objectForKey:@"_user"], nilUserId);
}

- (void)testRequestTooLargeBackoffLogic {
    [self.rakam setEventUploadThreshold:2];
    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:413 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"response" dataUsingEncoding:NSUTF8StringEncoding]
            }];

    // 413 error force backoff with 2 events --> new upload limit will be 1
    [self setupAsyncResponse:_connectionMock response:serverResponse];
    [self.rakam logEvent:@"test"];
    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];

    // after first 413, the backoffupload batch size should now be 1
    XCTAssertTrue(self.rakam.backoffUpload);
    XCTAssertEqual(self.rakam.backoffUploadBatchSize, 1);
    XCTAssertEqual(_connectionCallCount, 1);
}

- (void)testRequestTooLargeBackoffRemoveEvent {
    [self.rakam setEventUploadThreshold:1];
    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:413 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"response" dataUsingEncoding:NSUTF8StringEncoding]
            }];

    // 413 error force backoff with 1 events --> should drop the event
    [self setupAsyncResponse:_connectionMock response:serverResponse];
    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];

    // after first 413, the backoffupload batch size should now be 1
    XCTAssertTrue(self.rakam.backoffUpload);
    XCTAssertEqual(self.rakam.backoffUploadBatchSize, 1);
    XCTAssertEqual(_connectionCallCount, 1);
    XCTAssertEqual([self.databaseHelper getEventCount], 0);
}

- (void)testIdentify {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam setEventUploadThreshold:2];

    RakamIdentify *identify = [[RakamIdentify identify] set:@"key1" value:@"value1"];
    [self.rakam identify:identify];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    XCTAssertEqual([dbHelper getTotalEventCount], 1);

    NSDictionary *operations = [NSDictionary dictionaryWithObject:@"value1" forKey:@"key1"];
    NSDictionary *event = [self.rakam getLastIdentify];
    XCTAssertEqualObjects([((NSDictionary *) [event objectForKey:@"properties"]) objectForKey:@"$set"], operations);

    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:200 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"success" dataUsingEncoding:NSUTF8StringEncoding]
            }];
    [self setupAsyncResponse:_connectionMock response:serverResponse];
    RakamIdentify *identify2 = [[[RakamIdentify alloc] init] set:@"key2" value:@"value2"];
    [self.rakam identify:identify2];
    SAFE_ARC_RELEASE(identify2);
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 0);
    XCTAssertEqual([dbHelper getTotalEventCount], 0);
}

- (void)testLogRevenue {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];

    // ignore invalid revenue objects
    [self.rakam logRevenue:nil];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 0);

    [self.rakam logRevenue:[RakamRevenue revenue]];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 0);

    // log valid revenue object
    NSNumber *price = [NSNumber numberWithDouble:15.99];
    NSInteger quantity = 15;
    NSString *productId = @"testProductId";
    NSString *revenueType = @"testRevenueType";
    NSDictionary *props = [NSDictionary dictionaryWithObject:@"San Francisco" forKey:@"city"];
    RakamRevenue *revenue = [[[[RakamRevenue revenue] setProductIdentifier:productId] setPrice:price] setQuantity:quantity];
    [[revenue setRevenueType:revenueType] setEventProperties:props];

    [self.rakam logRevenue:revenue];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 1);

    NSDictionary *event = [self.rakam getLastEvent];
    XCTAssertEqualObjects([event objectForKey:@"collection"], @"revenue_amount");

    NSDictionary *dict = [event objectForKey:@"properties"];
    XCTAssertEqualObjects([dict objectForKey:@"_product_id"], productId);
    XCTAssertEqualObjects([dict objectForKey:@"_price"], price);
    XCTAssertEqualObjects([dict objectForKey:@"_quantity"], [NSNumber numberWithInteger:quantity]);
    XCTAssertEqualObjects([dict objectForKey:@"_revenue_type"], revenueType);
    XCTAssertEqualObjects([dict objectForKey:@"city"], @"San Francisco");
}

- (void)test {
    [self.rakam setEventUploadThreshold:1];
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    [properties setObject:@"some event description" forKey:@"description"];
    [properties setObject:@"green" forKey:@"color"];
    [properties setObject:@"productIdentifier" forKey:@"_product_id"];
    [properties setObject:[NSNumber numberWithDouble:10.99] forKey:@"_price"];
    [properties setObject:[NSNumber numberWithInt:2] forKey:@"_quantity"];
    [self.rakam logEvent:@"Completed Purchase" withEventProperties:properties];
}

- (void)testMergeEventsAndIdentifys {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam setEventUploadThreshold:7];
    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:200 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"success" dataUsingEncoding:NSUTF8StringEncoding]
            }];
    [self setupAsyncResponse:_connectionMock response:serverResponse];

    [self.rakam logEvent:@"test_event1"];
    [self.rakam identify:[[RakamIdentify identify] add:@"photoCount" value:[NSNumber numberWithInt:1]]];
    [self.rakam logEvent:@"test_event2"];
    [self.rakam logEvent:@"test_event3"];
    [self.rakam logEvent:@"test_event4"];
    [self.rakam identify:[[RakamIdentify identify] set:@"gender" value:@"male"]];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 4);
    XCTAssertEqual([dbHelper getIdentifyCount], 2);
    XCTAssertEqual([dbHelper getTotalEventCount], 6);

    // verify merging
    NSMutableArray *events = [dbHelper getEvents:-1 limit:-1];
    NSMutableArray *identifys = [dbHelper getIdentifys:-1 limit:-1];
    NSDictionary *merged = [self.rakam mergeEventsAndIdentifys:events identifys:identifys numEvents:[dbHelper getTotalEventCount]];
    NSArray *mergedEvents = [merged objectForKey:@"events"];

    XCTAssertEqual(4, [[merged objectForKey:@"max_event_id"] intValue]);
    XCTAssertEqual(2, [[merged objectForKey:@"max_identify_id"] intValue]);
    XCTAssertEqual(6, [mergedEvents count]);

    XCTAssertEqualObjects([mergedEvents[0] objectForKey:@"collection"], @"test_event1");
    XCTAssertEqual([[mergedEvents[0] objectForKey:@"event_id"] intValue], 1);

    XCTAssertEqualObjects([mergedEvents[1] objectForKey:@"collection"], @"test_event2");
    XCTAssertEqual([[mergedEvents[1] objectForKey:@"event_id"] intValue], 2);

    XCTAssertEqualObjects([mergedEvents[2] objectForKey:@"collection"], @"test_event3");
    XCTAssertEqual([[mergedEvents[2] objectForKey:@"event_id"] intValue], 3);

    XCTAssertEqualObjects([mergedEvents[3] objectForKey:@"collection"], @"test_event4");
    XCTAssertEqual([[mergedEvents[3] objectForKey:@"event_id"] intValue], 4);

    XCTAssertEqualObjects([mergedEvents[4] objectForKey:@"collection"], @"$$user");
    XCTAssertEqual([[mergedEvents[4] objectForKey:@"event_id"] intValue], 1);
    XCTAssertTrue([self key:[mergedEvents[4] objectForKey:@"properties"]
       containsInDictionary:[NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:1] forKey:@"photoCount"] forKey:@"$add"]]);

    XCTAssertEqualObjects([mergedEvents[5] objectForKey:@"collection"], @"$$user");
    XCTAssertEqual([[mergedEvents[5] objectForKey:@"event_id"] intValue], 2);
    XCTAssertTrue([self key:[mergedEvents[5] objectForKey:@"properties"]
       containsInDictionary:[NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:@"male" forKey:@"gender"] forKey:@"$set"]]);

    [self.rakam identify:[[RakamIdentify identify] unset:@"karma"]];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 0);
    XCTAssertEqual([dbHelper getTotalEventCount], 0);
}

- (void)testMergeEventsBackwardsCompatible {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam identify:[[RakamIdentify identify] unset:@"key"]];
    [self.rakam logEvent:@"test_event"];
    [self.rakam flushQueue];

    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithDictionary:[self.rakam getLastEvent]];
    long eventId = [[event objectForKey:@"event_id"] longValue];
    [dbHelper removeEvent:eventId];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:event options:0 error:NULL];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    [dbHelper addEvent:jsonString];
    SAFE_ARC_RELEASE(jsonString);

    NSMutableArray *events = [dbHelper getEvents:-1 limit:-1];
    NSMutableArray *identifys = [dbHelper getIdentifys:-1 limit:-1];
    NSDictionary *merged = [self.rakam mergeEventsAndIdentifys:events identifys:identifys numEvents:[dbHelper getTotalEventCount]];
    NSArray *mergedEvents = [merged objectForKey:@"events"];
    XCTAssertEqualObjects([mergedEvents[0] objectForKey:@"collection"], @"test_event");
    XCTAssertEqualObjects([mergedEvents[1] objectForKey:@"collection"], @"$$user");
}

- (void)testTruncateLongStrings {
    NSString *longString = [@"" stringByPaddingToLength:kRKMMaxStringLength * 2 withString:@"c" startingAtIndex:0];
    XCTAssertEqual([longString length], kRKMMaxStringLength * 2);
    NSString *truncatedString = [self.rakam truncate:longString];
    XCTAssertEqual([truncatedString length], kRKMMaxStringLength);
    XCTAssertEqualObjects(truncatedString, [@"" stringByPaddingToLength:kRKMMaxStringLength withString:@"c" startingAtIndex:0]);

    NSString *shortString = [@"" stringByPaddingToLength:kRKMMaxStringLength - 1 withString:@"c" startingAtIndex:0];
    XCTAssertEqual([shortString length], kRKMMaxStringLength - 1);
    truncatedString = [self.rakam truncate:shortString];
    XCTAssertEqual([truncatedString length], kRKMMaxStringLength - 1);
    XCTAssertEqualObjects(truncatedString, shortString);
}

- (void)testTruncateNullObjects {
    XCTAssertNil([self.rakam truncate:nil]);
}

- (void)testTruncateDictionary {
    NSString *longString = [@"" stringByPaddingToLength:kRKMMaxStringLength * 2 withString:@"c" startingAtIndex:0];
    NSString *truncString = [@"" stringByPaddingToLength:kRKMMaxStringLength withString:@"c" startingAtIndex:0];
    NSMutableDictionary *object = [NSMutableDictionary dictionary];
    [object setValue:[NSNumber numberWithInt:10] forKey:@"int value"];
    [object setValue:[NSNumber numberWithBool:NO] forKey:@"bool value"];
    [object setValue:longString forKey:@"long string"];
    [object setValue:[NSArray arrayWithObject:longString] forKey:@"array"];
    [object setValue:longString forKey:RKM_REVENUE_RECEIPT];

    object = [self.rakam truncate:object];
    XCTAssertEqual([[object objectForKey:@"int value"] intValue], 10);
    XCTAssertFalse([[object objectForKey:@"bool value"] boolValue]);
    XCTAssertEqual([[object objectForKey:@"long string"] length], kRKMMaxStringLength);
    XCTAssertEqual([[object objectForKey:@"array"] count], 1);
    XCTAssertEqualObjects([object objectForKey:@"array"][0], truncString);
    XCTAssertEqual([[object objectForKey:@"array"][0] length], kRKMMaxStringLength);

    // receipt field should not be truncated
    XCTAssertEqualObjects([object objectForKey:RKM_REVENUE_RECEIPT], longString);
}

- (void)testTruncateEventAndIdentify {
    NSString *longString = [@"" stringByPaddingToLength:kRKMMaxStringLength * 2 withString:@"c" startingAtIndex:0];
    NSString *truncString = [@"" stringByPaddingToLength:kRKMMaxStringLength withString:@"c" startingAtIndex:0];

    NSDictionary *props = [NSDictionary dictionaryWithObjectsAndKeys:longString, @"long_string", longString, RKM_REVENUE_RECEIPT, nil];
    [self.rakam logEvent:@"test" withEventProperties:props];
    [self.rakam identify:[[RakamIdentify identify] set:@"long_string" value:longString]];
    [self.rakam flushQueue];

    NSDictionary *event = [self.rakam getLastEvent];
    NSDictionary *expected = [NSDictionary dictionaryWithObjectsAndKeys:truncString, @"long_string", longString, RKM_REVENUE_RECEIPT, nil];
    XCTAssertEqualObjects([event objectForKey:@"collection"], @"test");
    XCTAssertTrue([self key:[event objectForKey:@"properties"] containsInDictionary:expected]);

    NSDictionary *identify = [self.rakam getLastIdentify];
    XCTAssertEqualObjects([identify objectForKey:@"collection"], @"$$user");
    XCTAssertTrue([self key:[identify objectForKey:@"properties"] containsInDictionary:[NSDictionary dictionaryWithObject:[NSDictionary dictionaryWithObject:truncString forKey:@"long_string"] forKey:@"$set"]]);
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

- (void)testAutoIncrementSequenceNumber {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    int limit = 10;
    for (int i = 0; i < limit; i++) {
        XCTAssertEqual([self.rakam getNextSequenceNumber], i + 1);
        XCTAssertEqual([[dbHelper getLongValue:@"sequence_number"] intValue], i + 1);
    }
}

- (void)testSetOffline {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:200 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"success" dataUsingEncoding:NSUTF8StringEncoding]
            }];
    [self setupAsyncResponse:_connectionMock response:serverResponse];

    [self.rakam setOffline:YES];
    [self.rakam logEvent:@"test"];
    [self.rakam logEvent:@"test"];
    [self.rakam identify:[[RakamIdentify identify] set:@"key" value:@"value"]];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 2);
    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    XCTAssertEqual([dbHelper getTotalEventCount], 3);

    [self.rakam setOffline:NO];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 0);
    XCTAssertEqual([dbHelper getTotalEventCount], 0);
}

- (void)testSetOfflineTruncate {
    int eventMaxCount = 3;
    self.rakam.eventMaxCount = eventMaxCount;

    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    NSMutableDictionary *serverResponse = [NSMutableDictionary dictionaryWithDictionary:
            @{@"response": [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"/"] statusCode:200 HTTPVersion:nil headerFields:@{}],
                    @"data": [@"success" dataUsingEncoding:NSUTF8StringEncoding]
            }];
    [self setupAsyncResponse:_connectionMock response:serverResponse];

    [self.rakam setOffline:YES];
    [self.rakam logEvent:@"test1"];
    [self.rakam logEvent:@"test2"];
    [self.rakam logEvent:@"test3"];
    [self.rakam identify:[[RakamIdentify identify] unset:@"key1"]];
    [self.rakam identify:[[RakamIdentify identify] unset:@"key2"]];
    [self.rakam identify:[[RakamIdentify identify] unset:@"key3"]];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 3);
    XCTAssertEqual([dbHelper getIdentifyCount], 3);
    XCTAssertEqual([dbHelper getTotalEventCount], 6);

    [self.rakam logEvent:@"test4"];
    [self.rakam identify:[[RakamIdentify identify] unset:@"key4"]];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 3);
    XCTAssertEqual([dbHelper getIdentifyCount], 3);
    XCTAssertEqual([dbHelper getTotalEventCount], 6);

    NSMutableArray *events = [dbHelper getEvents:-1 limit:-1];
    XCTAssertEqual([events count], 3);
    XCTAssertEqualObjects([events[0] objectForKey:@"collection"], @"test2");
    XCTAssertEqualObjects([events[1] objectForKey:@"collection"], @"test3");
    XCTAssertEqualObjects([events[2] objectForKey:@"collection"], @"test4");

    NSMutableArray *identifys = [dbHelper getIdentifys:-1 limit:-1];
    XCTAssertEqual([identifys count], 3);
    XCTAssertEqualObjects([[[identifys[0] objectForKey:@"properties"] objectForKey:@"$unset"] objectForKey:@"key2"], @"-");
    XCTAssertEqualObjects([[[identifys[1] objectForKey:@"properties"] objectForKey:@"$unset"] objectForKey:@"key3"], @"-");
    XCTAssertEqualObjects([[[identifys[2] objectForKey:@"properties"] objectForKey:@"$unset"] objectForKey:@"key4"], @"-");


    [self.rakam setOffline:NO];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 0);
    XCTAssertEqual([dbHelper getTotalEventCount], 0);
}

- (void)testTruncateEventsQueues {
    int eventMaxCount = 50;
    XCTAssertGreaterThanOrEqual(eventMaxCount, kRKMEventRemoveBatchSize);
    self.rakam.eventMaxCount = eventMaxCount;

    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam setOffline:YES];
    for (int i = 0; i < eventMaxCount; i++) {
        [self.rakam logEvent:@"test"];
    }
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], eventMaxCount);

    [self.rakam logEvent:@"test"];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], eventMaxCount - (eventMaxCount / 10) + 1);
}

- (void)testTruncateEventsQueuesWithOneEvent {
    int eventMaxCount = 1;
    self.rakam.eventMaxCount = eventMaxCount;

    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam logEvent:@"test1"];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], eventMaxCount);

    [self.rakam logEvent:@"test2"];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], eventMaxCount);

    NSDictionary *event = [self.rakam getLastEvent];
    XCTAssertEqualObjects([event objectForKey:@"collection"], @"test2");
}

- (void)testInvalidJSONEventProperties {
    NSURL *url = [NSURL URLWithString:@"https://rakam.io/"];
    NSDictionary *properties = [NSDictionary dictionaryWithObjectsAndKeys:url, url, url, @"url", nil];
    [self.rakam logEvent:@"test" withEventProperties:properties];
    [self.rakam flushQueue];
    XCTAssertEqual([[RakamDatabaseHelper getDatabaseHelper] getEventCount], 1);
}

- (void)testClearUserProperties {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam setEventUploadThreshold:2];

    [self.rakam clearUserProperties];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 0);
    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    XCTAssertEqual([dbHelper getTotalEventCount], 1);

    NSDictionary *event = [self.rakam getLastIdentify];
    XCTAssertEqualObjects([event objectForKey:@"collection"], IDENTIFY_EVENT);
    XCTAssertEqualObjects([((NSDictionary *) [event objectForKey:@"properties"]) objectForKey:@"$clearAll"], @"-");
}

- (void)testUnarchiveEventsDict {
    NSString *archiveName = @"test_archive";
    NSDictionary *event = [NSDictionary dictionaryWithObject:@"test event" forKey:@"collection"];
    XCTAssertTrue([self.rakam archive:event toFile:archiveName]);

    NSDictionary *unarchived = [self.rakam unarchive:archiveName];
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_4) {
        XCTAssertEqualObjects(unarchived, event);
    } else {
        XCTAssertNil(unarchived);
    }
}

- (void)testBlockTooManyProperties {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];

    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    NSMutableDictionary *userProperties = [NSMutableDictionary dictionary];
    RakamIdentify *identify = [RakamIdentify identify];
    for (int i = 0; i < kRKMMaxPropertyKeys + 1; i++) {
        [eventProperties setObject:[NSNumber numberWithInt:i] forKey:[NSNumber numberWithInt:i]];
        [userProperties setObject:[NSNumber numberWithInt:i * 2] forKey:[NSNumber numberWithInt:i * 2]];
        [identify setOnce:[NSString stringWithFormat:@"%d", i] value:[NSNumber numberWithInt:i]];
    }

    // verify that setUserProperties ignores dict completely
    [self.rakam setUserProperties:userProperties];
    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getIdentifyCount], 0);

    // verify that event properties and user properties are scrubbed
    [self.rakam logEvent:@"test event" withEventProperties:eventProperties];
    [self.rakam identify:identify];
    [self.rakam flushQueue];

    XCTAssertEqual([dbHelper getEventCount], 1);

    XCTAssertEqual([dbHelper getIdentifyCount], 1);
    NSDictionary *identifyEvent = [self.rakam getLastIdentify];
    XCTAssertEqualObjects([((NSDictionary *) identifyEvent[@"properties"]) objectForKey:@"$setOnce"], [NSDictionary dictionary]);
}

- (void)testLogEventWithTimestamp {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1000];
    NSNumber *timestamp = [NSNumber numberWithLongLong:[date timeIntervalSince1970]];

    [self.rakam logEvent:@"test" withEventProperties:nil withGroups:nil withTimestamp:timestamp outOfSession:NO];
    [self.rakam flushQueue];
    NSDictionary *event = [self.rakam getLastEvent];
    XCTAssertEqual(1000, [[((NSDictionary *) [event objectForKey:@"properties"]) objectForKey:@"_time"] longLongValue]);

    [self.rakam logEvent:@"test2" withEventProperties:nil withGroups:nil withLongLongTimestamp:2000 outOfSession:NO];
    [self.rakam flushQueue];
    event = [self.rakam getLastEvent];
    XCTAssertEqual(2000, [[((NSDictionary *) [event objectForKey:@"properties"]) objectForKey:@"_time"] longLongValue]);
}

- (void)testRegenerateDeviceId {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];
    [self.rakam flushQueue];
    NSString *oldDeviceId = [self.rakam getDeviceId];
    XCTAssertFalse([RakamUtils isEmptyString:oldDeviceId]);
    XCTAssertEqualObjects(oldDeviceId, [dbHelper getValue:@"device_id"]);

    [self.rakam regenerateDeviceId];
    [self.rakam flushQueue];
    NSString *newDeviceId = [self.rakam getDeviceId];
    XCTAssertNotEqualObjects(oldDeviceId, newDeviceId);
    XCTAssertEqualObjects(newDeviceId, [dbHelper getValue:@"device_id"]);
    XCTAssertTrue([newDeviceId hasSuffix:@"R"]);
}

@end
