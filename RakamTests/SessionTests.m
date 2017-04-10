//
//  SessionTests.m
//  SessionTests
//
//  Created by Curtis on 9/24/14.
//  Copyright (c) 2014 Rakam. All rights reserved.
//
//  NOTE: Having a lot of OCMock partialMockObjects causes tests to be flakey.
//        Combined a lot of tests into one large test so they share a single
//        mockRakam object instead creating lots of separate ones.
//        This seems to have fixed the flakiness issue.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "Rakam.h"
#import "Rakam+Test.h"
#import "BaseTestCase.h"

@interface SessionTests : BaseTestCase

@end

@implementation SessionTests { }

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testSessionAutoStartedBackground {
    // mock application state
    id mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[mockApplication stub] andReturn:mockApplication] sharedApplication];
    OCMStub([mockApplication applicationState]).andReturn(UIApplicationStateBackground);

    // mock rakam object and verify enterForeground not called
    id mockRakam = [OCMockObject partialMockForObject:self.rakam];
    [[mockRakam reject] enterForeground];
    [mockRakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [mockRakam flushQueueWithQueue:[mockRakam initializerQueue]];
    [mockRakam flushQueue];
    [mockRakam verify];
    XCTAssertEqual([mockRakam queuedEventCount], 0);
}

- (void)testSessionAutoStartedInactive {
    id mockApplication = [OCMockObject niceMockForClass:[UIApplication class]];
    [[[mockApplication stub] andReturn:mockApplication] sharedApplication];
    OCMStub([mockApplication applicationState]).andReturn(UIApplicationStateInactive);

    id mockRakam = [OCMockObject partialMockForObject:self.rakam];
    [[mockRakam expect] enterForeground];
    [mockRakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey];
    [mockRakam flushQueueWithQueue:[mockRakam initializerQueue]];
    [mockRakam flushQueue];
    [mockRakam verify];
    XCTAssertEqual([mockRakam queuedEventCount], 0);
}

- (void)testSessionHandling {

    // start new session on initializeApiKey
    id mockRakam = [OCMockObject partialMockForObject:self.rakam];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1000];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date)] currentTime];

    [mockRakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey userId:nil];
    [mockRakam flushQueueWithQueue:[mockRakam initializerQueue]];
    [mockRakam flushQueue];
    XCTAssertEqual([mockRakam queuedEventCount], 0);
    XCTAssertEqual([mockRakam sessionId], 1000000);

    // also test getSessionId
    XCTAssertEqual([mockRakam getSessionId], 1000000);

    // A new session should start on UIApplicationWillEnterForeground after minTimeBetweenSessionsMillis
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date)] currentTime];
    [mockRakam enterBackground]; // simulate app entering background
    [mockRakam flushQueue];
    XCTAssertEqual([mockRakam sessionId], 1000000);

    NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:1000 + (self.rakam.minTimeBetweenSessionsMillis / 1000)];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date2)] currentTime];
    [mockRakam enterForeground]; // simulate app entering foreground
    [mockRakam flushQueue];

    XCTAssertEqual([mockRakam queuedEventCount], 0);
    XCTAssertEqual([mockRakam sessionId], 1000000 + self.rakam.minTimeBetweenSessionsMillis);


    // An event should continue the session in the foreground after minTimeBetweenSessionsMillis + 1 seconds
    NSDate *date3 = [NSDate dateWithTimeIntervalSince1970:1000 + (self.rakam.minTimeBetweenSessionsMillis / 1000) + 1];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date3)] currentTime];
    [mockRakam logEvent:@"continue_session"];
    [mockRakam flushQueue];

    XCTAssertEqual([[mockRakam lastEventTime] longLongValue], 1001000 + self.rakam.minTimeBetweenSessionsMillis);
    XCTAssertEqual([mockRakam queuedEventCount], 1);
    XCTAssertEqual([mockRakam sessionId], 1000000 + self.rakam.minTimeBetweenSessionsMillis);


    // session should continue on UIApplicationWillEnterForeground after minTimeBetweenSessionsMillis - 1 second
    NSDate *date4 = [NSDate dateWithTimeIntervalSince1970:2000];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date4)] currentTime];
    [mockRakam enterBackground]; // simulate app entering background

    NSDate *date5 = [NSDate dateWithTimeIntervalSince1970:2000 + (self.rakam.minTimeBetweenSessionsMillis / 1000) - 1];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date5)] currentTime];
    [mockRakam enterForeground]; // simulate app entering foreground
    [mockRakam flushQueue];

    XCTAssertEqual([mockRakam queuedEventCount], 1);
    XCTAssertEqual([mockRakam sessionId], 1000000 + self.rakam.minTimeBetweenSessionsMillis);


   // test out of session event
    NSDate *date6 = [NSDate dateWithTimeIntervalSince1970:3000];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date6)] currentTime];
    [mockRakam logEvent:@"No Session" withEventProperties:nil outOfSession:NO];
    [mockRakam flushQueue];
    XCTAssert([[mockRakam getLastEvent][@"properties"][@"session_id"]
               isEqualToNumber:[NSNumber numberWithLongLong:1000000 + self.rakam.minTimeBetweenSessionsMillis]]);

    NSDate *date7 = [NSDate dateWithTimeIntervalSince1970:3001];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date7)] currentTime];
    // An out of session event should have session_id = -1
    [mockRakam logEvent:@"No Session" withEventProperties:nil outOfSession:YES];
    [mockRakam flushQueue];
    XCTAssert([[mockRakam getLastEvent][@"properties"][@"session_id"]
               isEqualToNumber:[NSNumber numberWithLongLong:-1]]);

    // An out of session event should not continue the session
    XCTAssertEqual([[mockRakam lastEventTime] longLongValue], 3000000); // event time of first no session
}

- (void)testEnterBackgroundDoesNotTrackEvent {
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : apiKey userId:nil];
    [self.rakam flushQueueWithQueue:self.rakam.initializerQueue];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:UIApplicationDidEnterBackgroundNotification object:nil userInfo:nil];

    [self.rakam flushQueue];
    XCTAssertEqual([self.rakam queuedEventCount], 0);
}

- (void)testTrackSessionEvents {
    id mockRakam = [OCMockObject partialMockForObject:self.rakam];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1000];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date)] currentTime];
    [mockRakam setTrackingSessionEvents:YES];

    [mockRakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey userId:nil];
    [mockRakam flushQueueWithQueue:[mockRakam initializerQueue]];
    [mockRakam flushQueue];

    XCTAssertEqual([mockRakam queuedEventCount], 1);
    XCTAssertEqual([[mockRakam getLastEvent][@"properties"][@"session_id"] longLongValue], 1000000);
    XCTAssertEqualObjects([mockRakam getLastEvent][@"collection"], kRKMSessionStartEvent);


    // test end session with tracking session events
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date)] currentTime];
    [mockRakam enterBackground]; // simulate app entering background

    NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:1000 + (self.rakam.minTimeBetweenSessionsMillis / 1000)];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date2)] currentTime];
    [mockRakam enterForeground]; // simulate app entering foreground
    [mockRakam flushQueue];
    XCTAssertEqual([mockRakam queuedEventCount], 3);

    long long expectedSessionId = 1000000 + self.rakam.minTimeBetweenSessionsMillis;
    XCTAssertEqual([mockRakam sessionId], expectedSessionId);

    XCTAssertEqual([[self.rakam getEvent:1][@"properties"][@"session_id"] longLongValue], 1000000);
    XCTAssertEqualObjects([self.rakam getEvent:1][@"collection"], kRKMSessionEndEvent);
    XCTAssertEqual([[self.rakam getEvent:1][@"properties"][@"_time"] longLongValue], 1000000);

    XCTAssertEqual([[self.rakam getLastEvent][@"properties"][@"session_id"] longLongValue], expectedSessionId);
    XCTAssertEqualObjects([self.rakam getLastEvent][@"collection"], kRKMSessionStartEvent);

    // test in session identify with app in background
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date2)] currentTime];
    [mockRakam enterBackground]; // simulate app entering background

    NSDate *date3 = [NSDate dateWithTimeIntervalSince1970:1000 + 2 * self.rakam.minTimeBetweenSessionsMillis];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date3)] currentTime];
    RakamIdentify *identify = [[RakamIdentify identify] set:@"key" value:@"value"];
    [mockRakam identify:identify outOfSession:NO];
    [mockRakam flushQueue];
    XCTAssertEqual([mockRakam queuedEventCount], 5); // triggers session events

    // test out of session identify with app in background
    NSDate *date4 = [NSDate dateWithTimeIntervalSince1970:1000 + 3 * self.rakam.minTimeBetweenSessionsMillis];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date4)] currentTime];
    [mockRakam identify:identify outOfSession:YES];
    [mockRakam flushQueue];
    XCTAssertEqual([mockRakam queuedEventCount], 5); // does not trigger session events
}

- (void)testSessionEventsOn32BitDevices {
    id mockRakam = [OCMockObject partialMockForObject:self.rakam];
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:21474836470];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date)] currentTime];
    [mockRakam setTrackingSessionEvents:YES];

    [mockRakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] :apiKey userId:nil];
    [mockRakam flushQueueWithQueue:[mockRakam initializerQueue]];
    [mockRakam flushQueue];

    XCTAssertEqual([mockRakam queuedEventCount], 1);
    XCTAssertEqual([[mockRakam getLastEvent][@"properties"][@"session_id"] longLongValue], 21474836470000);
    XCTAssertEqualObjects([mockRakam getLastEvent][@"collection"], kRKMSessionStartEvent);


    // test end session with tracking session events
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date)] currentTime];
    [mockRakam enterBackground]; // simulate app entering background

    NSDate *date2 = [NSDate dateWithTimeIntervalSince1970:214748364700];
    [[[mockRakam expect] andReturnValue:OCMOCK_VALUE(date2)] currentTime];
    [mockRakam enterForeground]; // simulate app entering foreground
    [self.rakam flushQueue];
    XCTAssertEqual([mockRakam queuedEventCount], 3);

    XCTAssertEqual([mockRakam sessionId], 214748364700000);

    XCTAssertEqual([[self.rakam getEvent:1][@"properties"][@"session_id"] longLongValue], 21474836470000);
    XCTAssertEqualObjects([self.rakam getEvent:1][@"collection"], kRKMSessionEndEvent);

    XCTAssertEqual([[self.rakam getLastEvent][@"properties"][@"session_id"] longLongValue], 214748364700000);
    XCTAssertEqualObjects([self.rakam getLastEvent][@"collection"], kRKMSessionStartEvent);
}

- (void)testSkipSessionCheckWhenLoggingSessionEvents {
    RakamDatabaseHelper *dbHelper = [RakamDatabaseHelper getDatabaseHelper];

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:1000];
    NSNumber *timestamp = [NSNumber numberWithLongLong:[date timeIntervalSince1970] * 1000];
    [dbHelper insertOrReplaceKeyLongValue:@"previous_session_id" value:timestamp];

    self.rakam.trackingSessionEvents = YES;
    [self.rakam initializeApiKey:[NSURL URLWithString:@"http://127.0.0.1:9998"] : apiKey userId:nil];

    [self.rakam flushQueue];
    XCTAssertEqual([dbHelper getEventCount], 2);
    NSArray *events = [dbHelper getEvents:-1 limit:2];
    XCTAssertEqualObjects(events[0][@"collection"], kRKMSessionEndEvent);
    XCTAssertEqualObjects(events[1][@"collection"], kRKMSessionStartEvent);
}

@end
