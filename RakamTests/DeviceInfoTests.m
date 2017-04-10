//
//  DeviceInfoTests.m
//  DeviceInfoTests
//
//  Created by Allan on 4/21/15.
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import <OCMock/OCMock.h>
#import "RakamConstants.h"
#import "RakamDeviceInfo.h"
#import "RakamARCMacros.h"

@interface DeviceInfoTests : XCTestCase

@end

@implementation DeviceInfoTests {
    RakamDeviceInfo *_deviceInfo;
}

- (void)setUp {
    [super setUp];
    _deviceInfo = [[RakamDeviceInfo alloc] init];
}

- (void)tearDown {
    SAFE_ARC_RELEASE(_deviceInfo);
    [super tearDown];
}

- (void) testAppVersion {
    id mockBundle = [OCMockObject niceMockForClass:[NSBundle class]];
    [[[mockBundle stub] andReturn:mockBundle] mainBundle];
    NSDictionary *mockDictionary = @{
        @"CFBundleShortVersionString": kRKMVersion
    };
    OCMStub([mockBundle infoDictionary]).andReturn(mockDictionary);
    
    XCTAssertEqualObjects(kRKMVersion, _deviceInfo.appVersion);
    [mockBundle stopMocking];
}

- (void) testOsName {
    XCTAssertEqualObjects(@"ios", _deviceInfo.osName);
}

- (void) testOsVersion {
    XCTAssertEqualObjects([[UIDevice currentDevice] systemVersion], _deviceInfo.osVersion);
}

- (void) testManufacturer {
    XCTAssertEqualObjects(@"Apple", _deviceInfo.manufacturer);
}

- (void) testModel {
    XCTAssertEqualObjects(@"Simulator", _deviceInfo.model);
}

- (void) testCarrier {
    // TODO: Not sure how to test this on the simulator
//    XCTAssertEqualObjects(nil, _deviceInfo.carrier);
}

- (void) testCountry {
    XCTAssertEqualObjects(@"United States", _deviceInfo.country);
}

- (void) testLanguage {
    XCTAssertEqualObjects(@"English", _deviceInfo.language);
}

- (void) testAdvertiserID {
    // TODO: Not sure how to test this on the simulator
//    XCTAssertEqualObjects(nil, _deviceInfo.advertiserID);
}

- (void) testVendorID {
    // TODO: Not sure how to test this on the simulator
//    XCTAssertEqualObjects(nil, _deviceInfo.vendorID);
}


- (void) testGenerateUUID {
    NSString *a = [RakamDeviceInfo generateUUID];
    NSString *b = [RakamDeviceInfo generateUUID];
    XCTAssertNotNil(a);
    XCTAssertNotNil(b);
    XCTAssertNotEqual(a, b);
    XCTAssertNotEqual(a, b);
}

@end
