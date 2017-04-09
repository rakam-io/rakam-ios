//
//  RakamLocationManagerDelegateTests.m
//  RakamLocationManagerDelegateTests
//
//  Created by Curtis on 1/3/2015.
//  Copyright (c) 2015 Rakam. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UIKit/UIKit.h>
#import "RakamLocationManagerDelegate.h"


@interface RakamLocationManagerDelegateTests : XCTestCase

@end

@implementation RakamLocationManagerDelegateTests

RakamLocationManagerDelegate *locationManagerDelegate;
CLLocationManager *locationManager;

- (void)setUp {
    [super setUp];
    locationManager = [[CLLocationManager alloc] init];
    locationManagerDelegate = [[RakamLocationManagerDelegate alloc] init];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testDidFailWithError {
    [locationManagerDelegate locationManager:locationManager didFailWithError:nil];
    
}

- (void)testDidUpdateToLocation {
    [locationManagerDelegate locationManager:locationManager didUpdateToLocation:nil fromLocation:nil];
    
}

- (void)testDidChangeAuthorizationStatus {
    [locationManagerDelegate locationManager:locationManager
                didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorized];
    [locationManagerDelegate locationManager:locationManager
                didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorizedAlways];
    [locationManagerDelegate locationManager:locationManager
                didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorizedWhenInUse];
    
}
@end
