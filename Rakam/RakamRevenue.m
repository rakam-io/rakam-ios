//
//  RakamRevenue.m
//  Rakam
//
//  Created by Daniel Jih on 04/18/16.
//  Copyright © 2016 Rakam. All rights reserved.
//

#ifndef RAKAM_DEBUG
#define RAKAM_DEBUG 0
#endif

#ifndef RAKAM_LOG
#if RAKAM_DEBUG
#   define RAKAM_LOG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#   define RAKAM_LOG(...)
#endif
#endif

#import <Foundation/Foundation.h>
#import "RakamRevenue.h"
#import "RakamARCMacros.h"
#import "RakamConstants.h"
#import "RakamUtils.h"

@interface RakamRevenue()
@end

@implementation RakamRevenue{}

- (void)dealloc
{
    SAFE_ARC_RELEASE(_productId);
    SAFE_ARC_RELEASE(_price);
    SAFE_ARC_RELEASE(_revenueType);
    SAFE_ARC_RELEASE(_receipt);
    SAFE_ARC_RELEASE(_properties);
    SAFE_ARC_SUPER_DEALLOC();
}

- (id)init
{
    if ((self = [super init])) {
        _quantity = 1;
    }
    return self;
}

/*
 * Create an RakamRevenue object
 */
+ (instancetype)revenue
{
    return SAFE_ARC_AUTORELEASE([[self alloc] init]);
}

- (BOOL)isValidRevenue
{
    if (_price == nil) {
        NSLog(@"Invalid revenue, need to set price field");
        return NO;
    }
    return YES;
}

- (RakamRevenue*)setProductIdentifier:(NSString *) productIdentifier
{
    if ([RakamUtils isEmptyString:productIdentifier]) {
        RAKAM_LOG(@"Invalid empty productIdentifier");
        return self;
    }

    (void) SAFE_ARC_RETAIN(productIdentifier);
    SAFE_ARC_RELEASE(_productId);
    _productId = productIdentifier;
    return self;
}

- (RakamRevenue*)setQuantity:(NSInteger) quantity
{
    _quantity = quantity;
    return self;
}

- (RakamRevenue*)setPrice:(NSNumber *) price
{
    (void) SAFE_ARC_RETAIN(price);
    SAFE_ARC_RELEASE(_price);
    _price = price;
    return self;
}

- (RakamRevenue*)setRevenueType:(NSString*) revenueType
{
    (void) SAFE_ARC_RETAIN(revenueType);
    SAFE_ARC_RELEASE(_revenueType);
    _revenueType = revenueType;
    return self;
}

- (RakamRevenue*)setReceipt:(NSData*) receipt
{
    (void) SAFE_ARC_RETAIN(receipt);
    SAFE_ARC_RELEASE(_receipt);
    _receipt = receipt;
    return self;
}

- (RakamRevenue*)setEventProperties:(NSDictionary*) eventProperties
{
    eventProperties = [eventProperties copy];
    SAFE_ARC_RELEASE(_properties);
    _properties = eventProperties;
    return self;
}

- (NSDictionary*)toNSDictionary
{
    NSMutableDictionary *dict;
    if (_properties == nil) {
        dict = [[NSMutableDictionary alloc] init];
    } else {
        dict = [_properties mutableCopy];
    }

    [dict setValue:_productId forKey:RKM_REVENUE_PRODUCT_ID];
    [dict setValue:[NSNumber numberWithInteger:_quantity] forKey:RKM_REVENUE_QUANTITY];
    [dict setValue:_price forKey:RKM_REVENUE_PRICE];
    [dict setValue:_revenueType forKey:RKM_REVENUE_REVENUE_TYPE];

    if ([_receipt respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        [dict setValue:[_receipt base64EncodedStringWithOptions:0] forKey:RKM_REVENUE_RECEIPT];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
        [dict setValue:[_receipt base64Encoding] forKey:RKM_REVENUE_RECEIPT];
#pragma clang diagnostic pop
    }

    return SAFE_ARC_AUTORELEASE(dict);
}

@end
