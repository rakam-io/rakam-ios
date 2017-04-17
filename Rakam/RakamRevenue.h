//
//  RakamRevenue.h
//  Rakam
//
//  Created by Daniel Jih on 04/18/16.
//  Copyright © 2016 Rakam. All rights reserved.
//

/**
 `RKMRevenue` objects are a wrapper for revenue data, which get passed to the `logRevenue` method to send to Rakam servers.

 **Note:** price is a required field. If quantity is not specified, then defaults to 1.

 **Note:** Revenue amount is calculated as price * quantity.

 Each method updates a revenue property in the Revenue object, and returns the same Revenue object, allowing you to chain multiple method calls together.

 Here is an example of how to use `RKMRevenue` to send revenue data:

    RKMRevenue *revenue = [[[RKMRevenue revenue] setProductIdentifier:@"productIdentifier"] setQuantity:3];
    [revenue setPrice:[NSNumber numberWithDouble:3.99]];
    [[Rakam instance] logRevenue:revenue];

 See [Tracking Revenue](https://github.com/amplitude/Rakam-iOS#tracking-revenue) for more information about logging Revenue.
 */

@interface RakamRevenue : NSObject

/**-----------------------------------------------------------------------------
 * @name Required Revenue Fields
 * -----------------------------------------------------------------------------
 */

/**
 The product identifier for the transaction (optional).
 */
@property (nonatomic, strong, readonly) NSString *productId;

/**
 The price of product(s) in the transaction.

 @warning: required field
 */
@property (nonatomic, strong, readonly) NSNumber *price;

/**-----------------------------------------------------------------------------
 * @name Optional Revenue Fields
 * -----------------------------------------------------------------------------
 */

/**
 The quantity of product(s) purchased in the transaction.

 @warning: defaults to 1
 */
@property (nonatomic, readonly) NSInteger quantity;

/**
 The revenue type for the transaction (optional).
 */
@property (nonatomic, strong, readonly) NSString *revenueType;

/**
 The receipt data for the transaction. Required if you want to verify the revenue event.

 @see [Revenue Validation](https://github.com/amplitude/amplitude-ios#revenue-verification)
 */
@property (nonatomic, strong, readonly) NSData *receipt;

/**
 Event properties for the revenue event.

 @see [Setting Event Properties](https://github.com/amplitude/amplitude-ios#setting-event-properties)
 */
@property (nonatomic, strong, readonly) NSDictionary *properties;

/**-----------------------------------------------------------------------------
 * @name Creating an RKMRevenue Object
 * -----------------------------------------------------------------------------
 */

/**
 Creates a new [RKMRevenue](#) object.

 @returns a new [RKMRevenue](#) object.
 */
+ (instancetype)revenue;

/*
 private internal method to verify that all required revenue fields are set
 */
- (BOOL) isValidRevenue;

/**-----------------------------------------------------------------------------
 * @name Setter Methods for Revenue Fields
 * -----------------------------------------------------------------------------
 */

/**
 Set a value for the product identifier.

 @param productIdentifier The value for the product identifier. Empty strings are ignored.

 @returns the same [RKMRevenue](#) object, allowing you to chain multiple method calls together.
 */
- (RakamRevenue*)setProductIdentifier:(NSString*) productIdentifier;

/**
 Set a value for the quantity.

 **Note** revenue amount is calculated as price * quantity.

 @param quantity Integer value for the quantity. Defaults to 1 if not specified.

 @returns the same [RKMRevenue](#) object, allowing you to chain multiple method calls together.
 */
- (RakamRevenue*)setQuantity:(NSInteger) quantity;


/**
 Set a value for the price.

 **Note** revenue amount is calculated as price * quantity.

 @param price The value for the price.

 @returns the same [RKMRevenue](#) object, allowing you to chain multiple method calls together.
 */
- (RakamRevenue*)setPrice:(NSNumber*) price;


/**
 Set a value for the revenueType (for example purchase, cost, tax, refund, etc).

 @param revenueType String value for the revenue type.

 @returns the same [RKMRevenue](#) object, allowing you to chain multiple method calls together.
 */
- (RakamRevenue*)setRevenueType:(NSString*) revenueType;


/**
 Add the receipt data for the transaction. Reequired if you want to verify this revenue event.

 @param receipt The receipt data from the App Store.

 @returns the same [RKMRevenue](#) object, allowing you to chain multiple method calls together.

 @see [Revenue Validation](https://github.com/amplitude/amplitude-ios#revenue-verification)
 @see [Validating Receipts with the App Store](https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html#//apple_ref/doc/uid/TP40010573-CH104-SW1)
 */
- (RakamRevenue*)setReceipt:(NSData*) receipt;

/**
 Set event properties for the revenue event.

 @param eventProperties An `NSDictionary` of event properties to set for the revenue event.

 @returns the same [RKMRevenue](#) object, allowing you to chain multiple method calls together.

 @see [Setting Event Properties](https://github.com/amplitude/amplitude-ios#setting-event-properties)
 */
- (RakamRevenue*)setEventProperties:(NSDictionary*) eventProperties;


- (NSDictionary*)toNSDictionary;

@end
