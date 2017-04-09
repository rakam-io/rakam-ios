//
//  RakamIdentify.m
//  Rakam
//
//  Created by Daniel Jih on 10/5/15.
//  Copyright © 2015 Rakam. All rights reserved.
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
#import "RakamIdentify.h"
#import "RakamARCMacros.h"
#import "RakamConstants.h"
#import "RakamUtils.h"

@interface RakamIdentify()
@end

@implementation RakamIdentify
{
    NSMutableSet *_userProperties;
}

- (id)init
{
    if ((self = [super init])) {
        _userPropertyOperations = [[NSMutableDictionary alloc] init];
        _userProperties = [[NSMutableSet alloc] init];
    }
    return self;
}

+ (instancetype)identify
{
    return SAFE_ARC_AUTORELEASE([[self alloc] init]);
}

- (void)dealloc
{
    SAFE_ARC_RELEASE(_userPropertyOperations);
    SAFE_ARC_RELEASE(_userProperties);
    SAFE_ARC_SUPER_DEALLOC();
}

- (RakamIdentify*)add:(NSString*) property value:(NSObject*) value
{
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]]) {
        [self addToUserProperties:RKM_OP_ADD property:property value:value];
    } else {
        RAKAM_LOG(@"Unsupported value type for ADD operation, expecting NSNumber or NSString");
    }
    return self;
}

- (RakamIdentify*)append:(NSString*) property value:(NSObject*) value
{
    [self addToUserProperties:RKM_OP_APPEND property:property value:value];
    return self;
}

- (RakamIdentify*)clearAll
{
    if ([_userPropertyOperations count] > 0) {
        if ([_userPropertyOperations objectForKey:RKM_OP_CLEAR_ALL] == nil) {
            RAKAM_LOG(@"Need to send $clearAll on its own Identify object without any other operations, skipping $clearAll");
        }
        return self;
    }
    [_userPropertyOperations setObject:@"-" forKey:RKM_OP_CLEAR_ALL];
    return self;
}

- (RakamIdentify*)prepend:(NSString*) property value:(NSObject*) value
{
    [self addToUserProperties:RKM_OP_PREPEND property:property value:value];
    return self;
}

- (RakamIdentify*)set:(NSString*) property value:(NSObject*) value
{
    [self addToUserProperties:RKM_OP_SET property:property value:value];
    return self;
}

- (RakamIdentify*)setOnce:(NSString*) property value:(NSObject*) value
{
    [self addToUserProperties:RKM_OP_SET_ONCE property:property value:value];
    return self;
}

- (RakamIdentify*)unset:(NSString*) property
{
    [self addToUserProperties:RKM_OP_UNSET property:property value:@"-"];
    return self;
}

- (void)addToUserProperties:(NSString*)operation property:(NSString*) property value:(NSObject*) value
{
    if (value == nil) {
        RAKAM_LOG(@"Attempting to perform operation '%@' with nil value for property '%@', ignoring", operation, property);
        return;
    }

    // check that clearAll wasn't already used in this Identify
    if ([_userPropertyOperations objectForKey:RKM_OP_CLEAR_ALL] != nil) {
        RAKAM_LOG(@"This Identify already contains a $clearAll operation, ignoring operation %@", operation);
        return;
    }

    // check if property already used in a previous operation
    if ([_userProperties containsObject:property]) {
        RAKAM_LOG(@"Already used property '%@' in previous operation, ignoring for operation '%@'", property, operation);
        return;
    }

    NSMutableDictionary *operations = [_userPropertyOperations objectForKey:operation];
    if (operations == nil) {
        operations = [NSMutableDictionary dictionary];
        [_userPropertyOperations setObject:operations forKey:operation];
    }
    [operations setObject:[RakamUtils makeJSONSerializable:value] forKey:property];
    [_userProperties addObject:property];
}

@end
