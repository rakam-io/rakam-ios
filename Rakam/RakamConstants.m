//
//  RKMConstants.m

#import "RakamConstants.h"

NSString *const kRKMLibrary = @"rakam-ios";
NSString *const kRKMVersion = @"4.0.4";
NSString *const kRKMDefaultInstance = @"$default_instance";
const int kRKMApiVersion = 3;
const int kRKMDBVersion = 3;
const int kRKMDBFirstVersion = 2; // to detect if DB exists yet

// for tvOS, upload events immediately, don't save too many events locally
#if TARGET_OS_TV
const int kRKMEventUploadThreshold = 1;
const int kRKMEventMaxCount = 100;
NSString *const kRKMPlatform = @"tvOS";
NSString *const kRKMOSName = @"tvos";
#else  // iOS
const int kRKMEventUploadThreshold = 30;
const int kRKMEventMaxCount = 1000;
NSString *const kRKMPlatform = @"iOS";
NSString *const kRKMOSName = @"ios";
#endif

const int kRKMEventUploadMaxBatchSize = 100;
const int kRKMEventRemoveBatchSize = 20;
const int kRKMEventUploadPeriodSeconds = 30; // 30s
const long kRKMMinTimeBetweenSessionsMillis = 5 * 60 * 1000; // 5m
const int kRKMMaxStringLength = 1024;
const int kRKMMaxPropertyKeys = 1000;

NSString *const IDENTIFY_EVENT = @"$$user";
NSString *const RKM_OP_ADD = @"$add";
NSString *const RKM_OP_APPEND = @"$append";
NSString *const RKM_OP_CLEAR_ALL = @"$clearAll";
NSString *const RKM_OP_PREPEND = @"$prepend";
NSString *const RKM_OP_SET = @"$set";
NSString *const RKM_OP_SET_ONCE = @"$setOnce";
NSString *const RKM_OP_UNSET = @"$unset";

NSString *const RKM_REVENUE_PRODUCT_ID = @"_product_id";
NSString *const RKM_REVENUE_QUANTITY = @"_quantity";
NSString *const RKM_REVENUE_PRICE = @"_price";
NSString *const RKM_REVENUE_REVENUE_TYPE = @"_revenue_type";
NSString *const RKM_REVENUE_RECEIPT = @"_receipt";
