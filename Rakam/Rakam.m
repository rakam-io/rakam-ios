//
// Rakam.m

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

#ifndef RAKAM_LOG_ERRORS
#define RAKAM_LOG_ERRORS 1
#endif

#ifndef RAKAM_ERROR
#if RAKAM_LOG_ERRORS
#   define RAKAM_ERROR(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#   define RAKAM_ERROR(...)
#endif
#endif


#import "Rakam.h"
#import "RakamLocationManagerDelegate.h"
#import "RakamARCMacros.h"
#import "RakamConstants.h"
#import "RakamDeviceInfo.h"
#import "RakamURLConnection.h"
#import "RakamDatabaseHelper.h"
#import "RakamUtils.h"
#import "RakamIdentify.h"
#import "RakamRevenue.h"
#import <math.h>
#import <sys/socket.h>
#import <sys/sysctl.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>
#include <sys/types.h>
#include <sys/sysctl.h>

@interface Rakam ()

@property(nonatomic, strong) NSOperationQueue *backgroundQueue;
@property(nonatomic, strong) NSOperationQueue *initializerQueue;
@property(nonatomic, strong) RakamDatabaseHelper *dbHelper;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, assign) BOOL sslPinningEnabled;
@property(nonatomic, assign) long long sessionId;
@property(nonatomic, assign) BOOL backoffUpload;
@property(nonatomic, assign) int backoffUploadBatchSize;

@end

NSString *const kRKMSessionStartEvent = @"session_start";
NSString *const kRKMSessionEndEvent = @"session_end";
NSString *const kRKMRevenueEvent = @"revenue_amount";

static NSString *const BACKGROUND_QUEUE_NAME = @"BACKGROUND";
static NSString *const DATABASE_VERSION = @"database_version";
static NSString *const DEVICE_ID = @"device_id";
static NSString *const EVENTS = @"events";
static NSString *const EVENT_ID = @"event_id";
static NSString *const PREVIOUS_SESSION_ID = @"previous_session_id";
static NSString *const PREVIOUS_SESSION_TIME = @"previous_session_time";
static NSString *const MAX_EVENT_ID = @"max_event_id";
static NSString *const MAX_IDENTIFY_ID = @"max_identify_id";
static NSString *const OPT_OUT = @"opt_out";
static NSString *const USER_ID = @"user_id";
static NSString *const SEQUENCE_NUMBER = @"sequence_number";


@implementation Rakam {
    NSString *_eventsDataPath;
    NSMutableDictionary *_propertyList;

    BOOL _updateScheduled;
    BOOL _updatingCurrently;
    UIBackgroundTaskIdentifier _uploadTaskID;

    RakamDeviceInfo *_deviceInfo;
    BOOL _useAdvertisingIdForDeviceId;

    CLLocation *_lastKnownLocation;
    BOOL _locationListeningEnabled;
    CLLocationManager *_locationManager;
    RakamLocationManagerDelegate *_locationManagerDelegate;

    BOOL _inForeground;
    BOOL _offline;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma mark - Static methods

+ (Rakam *)instance {
    return [Rakam instanceWithName:nil];
}

+ (Rakam *)instanceWithName:(NSString *)instanceName {
    static NSMutableDictionary *_instances = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instances = [[NSMutableDictionary alloc] init];
    });

    // compiler wants explicit key nil check even though RakamUtils isEmptyString already has one
    if (instanceName == nil || [RakamUtils isEmptyString:instanceName]) {
        instanceName = kRKMDefaultInstance;
    }
    instanceName = [instanceName lowercaseString];

    Rakam *client = nil;
    @synchronized (_instances) {
        client = [_instances objectForKey:instanceName];
        if (client == nil) {
            client = [[self alloc] initWithInstanceName:instanceName];
            [_instances setObject:client forKey:instanceName];
            SAFE_ARC_RELEASE(client);
        }
    }

    return client;
}

+ (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId {
    [[Rakam instance] initializeApiKey:apiUrl :apiKey userId:userId];
}

+ (void)logEvent:(NSString *)eventType {
    [[Rakam instance] logEvent:eventType];
}

+ (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties {
    [[Rakam instance] logEvent:eventType withEventProperties:eventProperties];
}

+ (void)uploadEvents {
    [[Rakam instance] uploadEvents];
}

+ (void)setUserProperties:(NSDictionary *)userProperties {
    [[Rakam instance] setUserProperties:userProperties];
}

+ (void)setUserId:(NSString *)userId {
    [[Rakam instance] setUserId:userId];
}

+ (void)enableLocationListening {
    [[Rakam instance] enableLocationListening];
}

+ (void)disableLocationListening {
    [[Rakam instance] disableLocationListening];
}

+ (void)useAdvertisingIdForDeviceId {
    [[Rakam instance] useAdvertisingIdForDeviceId];
}

+ (void)printEventsCount {
    [[Rakam instance] printEventsCount];
}

+ (NSString *)getDeviceId {
    return [[Rakam instance] getDeviceId];
}

+ (void)updateLocation {
    [[Rakam instance] updateLocation];
}

#pragma mark - Main class methods

- (id)init {
    return [self initWithInstanceName:nil];
}

- (id)initWithInstanceName:(NSString *)instanceName {
    if ([RakamUtils isEmptyString:instanceName]) {
        instanceName = kRKMDefaultInstance;
    }
    instanceName = [instanceName lowercaseString];

    if ((self = [super init])) {
        _initialized = NO;
        _locationListeningEnabled = YES;
        _sessionId = -1;
        _updateScheduled = NO;
        _updatingCurrently = NO;
        _useAdvertisingIdForDeviceId = NO;
        _backoffUpload = NO;
        _offline = NO;
        _instanceName = SAFE_ARC_RETAIN(instanceName);
        _dbHelper = SAFE_ARC_RETAIN([RakamDatabaseHelper getDatabaseHelper:instanceName]);

        self.eventUploadThreshold = kRKMEventUploadThreshold;
        self.eventMaxCount = kRKMEventMaxCount;
        self.eventUploadMaxBatchSize = kRKMEventUploadMaxBatchSize;
        self.eventUploadPeriodSeconds = kRKMEventUploadPeriodSeconds;
        self.minTimeBetweenSessionsMillis = kRKMMinTimeBetweenSessionsMillis;
        _backoffUploadBatchSize = self.eventUploadMaxBatchSize;

        _initializerQueue = [[NSOperationQueue alloc] init];
        _backgroundQueue = [[NSOperationQueue alloc] init];
        // Force method calls to happen in FIFO order by only allowing 1 concurrent operation
        [_backgroundQueue setMaxConcurrentOperationCount:1];
        // Ensure initialize finishes running asynchronously before other calls are run
        [_backgroundQueue setSuspended:YES];
        // Name the queue so runOnBackgroundQueue can tell which queue an operation is running
        _backgroundQueue.name = BACKGROUND_QUEUE_NAME;

        [_initializerQueue addOperationWithBlock:^{

            _deviceInfo = [[RakamDeviceInfo alloc] init];

            _uploadTaskID = UIBackgroundTaskInvalid;

            NSString *eventsDataDirectory = [RakamUtils platformDataDirectory];
            NSString *propertyListPath = [eventsDataDirectory stringByAppendingPathComponent:@"io.rakam.plist"];
            if (![_instanceName isEqualToString:kRKMDefaultInstance]) {
                propertyListPath = [NSString stringWithFormat:@"%@_%@", propertyListPath, _instanceName]; // namespace pList with instance name
            }
            _propertyListPath = SAFE_ARC_RETAIN(propertyListPath);
            _eventsDataPath = SAFE_ARC_RETAIN([eventsDataDirectory stringByAppendingPathComponent:@"io.rakam.archiveDict"]);
            [self upgradePrefs];

            // Load propertyList object
            _propertyList = SAFE_ARC_RETAIN([self deserializePList:_propertyListPath]);
            if (!_propertyList) {
                _propertyList = SAFE_ARC_RETAIN([NSMutableDictionary dictionary]);
                [_propertyList setObject:[NSNumber numberWithInt:1] forKey:DATABASE_VERSION];
                BOOL success = [self savePropertyList];
                if (!success) {
                    RAKAM_ERROR(@"ERROR: Unable to save propertyList to file on initialization");
                }
            } else {
                RAKAM_LOG(@"Loaded from %@", _propertyListPath);
            }

            // update database if necessary
            int oldDBVersion = 1;
            NSNumber *oldDBVersionSaved = [_propertyList objectForKey:DATABASE_VERSION];
            if (oldDBVersionSaved != nil) {
                oldDBVersion = [oldDBVersionSaved intValue];
            }

            // update the database
            if (oldDBVersion < kRKMDBVersion) {
                if ([self.dbHelper upgrade:oldDBVersion newVersion:kRKMDBVersion]) {
                    [_propertyList setObject:[NSNumber numberWithInt:kRKMDBVersion] forKey:DATABASE_VERSION];
                    [self savePropertyList];
                }
            }

            // only on default instance, migrate all of old _eventsData object to database store if database just created
            if ([_instanceName isEqualToString:kRKMDefaultInstance] && oldDBVersion < kRKMDBFirstVersion) {
                if ([self migrateEventsDataToDB]) {
                    // delete events data so don't need to migrate next time
                    if ([[NSFileManager defaultManager] fileExistsAtPath:_eventsDataPath]) {
                        [[NSFileManager defaultManager] removeItemAtPath:_eventsDataPath error:NULL];
                    }
                }
            }
            SAFE_ARC_RELEASE(_eventsDataPath);

            // try to restore previous session
            long long previousSessionId = [self previousSessionId];
            if (previousSessionId >= 0) {
                _sessionId = previousSessionId;
            }

            [self initializeDeviceId];

            [_backgroundQueue setSuspended:NO];
        }];

        // CLLocationManager must be created on the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            Class CLLocationManager = NSClassFromString(@"CLLocationManager");
            _locationManager = [[CLLocationManager alloc] init];
            _locationManagerDelegate = [[RakamLocationManagerDelegate alloc] init];
            SEL setDelegate = NSSelectorFromString(@"setDelegate:");
            [_locationManager performSelector:setDelegate withObject:_locationManagerDelegate];
        });

        [self addObservers];
    }
    return self;
}

// maintain backwards compatibility on default instance
- (BOOL)migrateEventsDataToDB {
    NSDictionary *eventsData = [self unarchive:_eventsDataPath];
    if (eventsData == nil) {
        return NO;
    }

    RakamDatabaseHelper *defaultDbHelper = [RakamDatabaseHelper getDatabaseHelper];
    BOOL success = YES;

    // migrate events
    NSArray *events = [eventsData objectForKey:EVENTS];
    for (id event in events) {
        NSError *error = nil;
        NSData *jsonData = nil;
        jsonData = [NSJSONSerialization dataWithJSONObject:[RakamUtils makeJSONSerializable:event] options:0 error:&error];
        if (error != nil) {
            RAKAM_ERROR(@"ERROR: NSJSONSerialization error: %@", error);
            continue;
        }
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if ([RakamUtils isEmptyString:jsonString]) {
            RAKAM_ERROR(@"ERROR: NSJSONSerialization resulted in a null string, skipping this event");
            if (jsonString != nil) {
                SAFE_ARC_RELEASE(jsonString);
            }
            continue;
        }
        success &= [defaultDbHelper addEvent:jsonString];
        SAFE_ARC_RELEASE(jsonString);
    }

    // migrate remaining properties
    NSString *userId = [eventsData objectForKey:USER_ID];
    if (userId != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyValue:USER_ID value:userId];
    }
    NSNumber *optOut = [eventsData objectForKey:OPT_OUT];
    if (optOut != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyLongValue:OPT_OUT value:optOut];
    }
    NSString *deviceId = [eventsData objectForKey:DEVICE_ID];
    if (deviceId != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyValue:DEVICE_ID value:deviceId];
    }
    NSNumber *previousSessionId = [eventsData objectForKey:PREVIOUS_SESSION_ID];
    if (previousSessionId != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_ID value:previousSessionId];
    }
    NSNumber *previousSessionTime = [eventsData objectForKey:PREVIOUS_SESSION_TIME];
    if (previousSessionTime != nil) {
        success &= [defaultDbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_TIME value:previousSessionTime];
    }

    return success;
}

- (void)addObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(enterForeground)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(enterBackground)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
}

- (void)removeObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [center removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)dealloc {
    [self removeObservers];

    // Release properties
    SAFE_ARC_RELEASE(_apiKey);
    SAFE_ARC_RELEASE(_backgroundQueue);
    SAFE_ARC_RELEASE(_deviceId);
    SAFE_ARC_RELEASE(_userId);

    // Release instance variables
    SAFE_ARC_RELEASE(_deviceInfo);
    SAFE_ARC_RELEASE(_initializerQueue);
    SAFE_ARC_RELEASE(_lastKnownLocation);
    SAFE_ARC_RELEASE(_locationManager);
    SAFE_ARC_RELEASE(_locationManagerDelegate);
    SAFE_ARC_RELEASE(_propertyList);
    SAFE_ARC_RELEASE(_propertyListPath);
    SAFE_ARC_RELEASE(_dbHelper);
    SAFE_ARC_RELEASE(_instanceName);


    SAFE_ARC_SUPER_DEALLOC();
}

- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey {
    [self initializeApiKey:apiUrl :apiKey userId:nil setUserId:NO];
}

/**
 * Initialize Rakam with a given apiKey and userId.
 */
- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId {
    [self initializeApiKey:apiUrl :apiKey userId:userId setUserId:YES];
}

/**
 * SetUserId: client explicitly initialized with a userId (can be nil).
 * If setUserId is NO, then attempt to load userId from saved eventsData.
 */
- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId setUserId:(BOOL)setUserId {
    if (apiKey == nil) {
        RAKAM_ERROR(@"ERROR: apiKey cannot be nil in initializeApiKey:");
        return;
    }
    if (apiUrl == nil) {
        RAKAM_ERROR(@"ERROR: apiUrl cannot be nil in initializeApiKey:");
        return;
    }

    if (![self isArgument:apiKey validType:[NSString class] methodName:@"initializeApiKey:"]) {
        return;
    }
    if (userId != nil && ![self isArgument:userId validType:[NSString class] methodName:@"initializeApiKey:"]) {
        return;
    }

    if ([apiKey length] == 0) {
        RAKAM_ERROR(@"ERROR: apiKey cannot be blank in initializeApiKey:");
        return;
    }

    if (!_initialized) {
        (void) SAFE_ARC_RETAIN(apiKey);
        (void) SAFE_ARC_RETAIN(apiUrl);
        SAFE_ARC_RELEASE(_apiKey);
        SAFE_ARC_RELEASE(_apiUrl);
        _apiKey = apiKey;

        NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@://%@:%@/%@",
                                                                              apiUrl.scheme, apiUrl.host, apiUrl.port, @"event/batch"]];
        _apiUrl = url.absoluteString;
        SAFE_ARC_RELEASE(url);

        [self runOnBackgroundQueue:^{
            if (setUserId) {
                [self setUserId:userId];
            } else {
                _userId = SAFE_ARC_RETAIN([self.dbHelper getValue:USER_ID]);
            }
        }];

        UIApplication *app = [self getSharedApplication];
        if (app != nil) {
            UIApplicationState state = app.applicationState;
            if (state != UIApplicationStateBackground) {
                // If this is called while the app is running in the background, for example
                // via a push notification, don't call enterForeground
                [self enterForeground];
            }
        }
        _initialized = YES;
    }
}

- (UIApplication *)getSharedApplication {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if (UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return [UIApplication performSelector:@selector(sharedApplication)];
    }
    return nil;
}

- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId startSession:(BOOL)startSession {
    [self initializeApiKey:apiUrl :apiKey userId:userId];
}

/**
 * Run a block in the background. If already in the background, run immediately.
 */
- (BOOL)runOnBackgroundQueue:(void (^)(void))block {
    if ([[NSOperationQueue currentQueue].name isEqualToString:BACKGROUND_QUEUE_NAME]) {
        RAKAM_LOG(@"Already running in the background.");
        block();
        return NO;
    } else {
        [_backgroundQueue addOperationWithBlock:block];
        return YES;
    }
}

#pragma mark - logEvent

- (void)logEvent:(NSString *)eventType {
    [self logEvent:eventType withEventProperties:nil];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties {
    [self logEvent:eventType withEventProperties:eventProperties withGroups:nil];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withGroups:nil outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups {
    [self logEvent:eventType withEventProperties:eventProperties withGroups:groups outOfSession:NO];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withUserProperties:nil withGroups:groups withTimestamp:nil outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups withLongLongTimestamp:(long long)timestamp outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withUserProperties:nil withGroups:groups withTimestamp:[NSNumber numberWithLongLong:timestamp] outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups withTimestamp:(NSNumber *)timestamp outOfSession:(BOOL)outOfSession {
    [self logEvent:eventType withEventProperties:eventProperties withUserProperties:nil withGroups:groups withTimestamp:timestamp outOfSession:outOfSession];
}

- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withUserProperties:(NSDictionary *)userProperties withGroups:(NSDictionary *)groups withTimestamp:(NSNumber *)timestamp outOfSession:(BOOL)outOfSession {
    if (_apiUrl == nil || _apiKey == nil) {
        RAKAM_ERROR(@"ERROR: apiUrl or apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling logEvent");
        return;
    }

    if (![self isArgument:eventType validType:[NSString class] methodName:@"logEvent"]) {
        return;
    }
    if (eventProperties != nil && ![self isArgument:eventProperties validType:[NSDictionary class] methodName:@"logEvent"]) {
        return;
    }

    if (timestamp == nil) {
        timestamp = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];
    }

    // Create snapshot of all event json objects, to prevent deallocation crash
    eventProperties = [eventProperties copy];
    userProperties = [userProperties copy];

    [self runOnBackgroundQueue:^{
        // Respect the opt-out setting by not sending or storing any events.
        if ([self optOut]) {
            RAKAM_LOG(@"User has opted out of tracking. Event %@ not logged.", eventType);
            SAFE_ARC_RELEASE(eventProperties);
            SAFE_ARC_RELEASE(userProperties);
            return;
        }

        // skip session check if logging start_session or end_session events
        BOOL loggingSessionEvent = _trackingSessionEvents && ([eventType isEqualToString:kRKMSessionStartEvent] || [eventType isEqualToString:kRKMSessionEndEvent]);
        if (!loggingSessionEvent && !outOfSession) {
            [self startOrContinueSession:timestamp];
        }

        NSMutableDictionary *event = [NSMutableDictionary dictionary];
        [event setValue:eventType forKey:@"collection"];

        NSMutableDictionary *realEventProperties = [NSMutableDictionary dictionary];
        [event setValue:realEventProperties forKey:@"properties"];
        [realEventProperties setValue:timestamp forKey:@"_time"];

        if ([eventType isEqualToString:IDENTIFY_EVENT]) {
            [realEventProperties addEntriesFromDictionary:[self truncate:
                    [RakamUtils makeJSONSerializable:[self replaceWithEmptyJSON:userProperties]]]];
        } else {
            [realEventProperties addEntriesFromDictionary:[self truncate:
                    [RakamUtils makeJSONSerializable:[self replaceWithEmptyJSON:eventProperties]]]];

            [realEventProperties setValue:[NSNumber numberWithLongLong:outOfSession ? -1 : _sessionId] forKey:@"session_id"];

            [self annotateEvent:realEventProperties];
        }

        SAFE_ARC_RELEASE(eventProperties);
        SAFE_ARC_RELEASE(userProperties);

        NSDictionary *api = @{
                @"library": @{
                        @"name": kRKMLibrary,
                        @"version": kRKMVersion
                },
                @"uuid": [RakamUtils generateUUID]
        };

        [event setValue:api forKey:@"api"];

        // convert event dictionary to JSON String
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:[RakamUtils makeJSONSerializable:event] options:0 error:&error];
        if (error != nil) {
            RAKAM_ERROR(@"ERROR: could not JSONSerialize event type %@: %@", eventType, error);
            return;
        }
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if ([RakamUtils isEmptyString:jsonString]) {
            RAKAM_ERROR(@"ERROR: JSONSerializing event type %@ resulted in an NULL string", eventType);
            if (jsonString != nil) {
                SAFE_ARC_RELEASE(jsonString);
            }
            return;
        }
        if ([eventType isEqualToString:IDENTIFY_EVENT]) {
            (void) [self.dbHelper addIdentify:jsonString];
        } else {
            (void) [self.dbHelper addEvent:jsonString];
        }
        SAFE_ARC_RELEASE(jsonString);

        RAKAM_LOG(@"Logged %@ Event", event[@"collection"]);

        [self truncateEventQueues];

        int eventCount = [self.dbHelper getTotalEventCount]; // refetch since events may have been deleted
        if ((eventCount % self.eventUploadThreshold) == 0 && eventCount >= self.eventUploadThreshold) {
            [self uploadEvents];
        } else {
            [self uploadEventsWithDelay:self.eventUploadPeriodSeconds];
        }
    }];
}

- (void)truncateEventQueues {
    int numEventsToRemove = MIN(MAX(1, self.eventMaxCount / 10), kRKMEventRemoveBatchSize);
    int eventCount = [self.dbHelper getEventCount];
    if (eventCount > self.eventMaxCount) {
        [self.dbHelper removeEvents:([self.dbHelper getNthEventId:numEventsToRemove])];
    }
    int identifyCount = [self.dbHelper getIdentifyCount];
    if (identifyCount > self.eventMaxCount) {
        [self.dbHelper removeIdentifys:([self.dbHelper getNthIdentifyId:numEventsToRemove])];
    }
}

- (void)annotateEvent:(NSMutableDictionary *)eventProperties {
    [eventProperties setValue:_userId forKey:@"_user"];
    [eventProperties setValue:_deviceId forKey:@"_device_id"];
    [eventProperties setValue:kRKMPlatform forKey:@"_platform"];
    [eventProperties setValue:_deviceInfo.appVersion forKey:@"_version_name"];
    [eventProperties setValue:_deviceInfo.osName forKey:@"_os_name"];
    [eventProperties setValue:_deviceInfo.osVersion forKey:@"_os_version"];
    [eventProperties setValue:_deviceInfo.model forKey:@"_device_model"];
    [eventProperties setValue:_deviceInfo.manufacturer forKey:@"_device_manufacturer"];
    [eventProperties setValue:_deviceInfo.carrier forKey:@"_carrier"];
    [eventProperties setValue:_deviceInfo.country forKey:@"_country"];
    [eventProperties setValue:_deviceInfo.language forKey:@"_language"];

    NSMutableDictionary *apiProperties = [eventProperties valueForKey:@"platform_specific"];

    NSString *advertiserID = _deviceInfo.advertiserID;
    if (advertiserID) {
        [apiProperties setValue:advertiserID forKey:@"ios_idfa"];
    }
    NSString *vendorID = _deviceInfo.vendorID;
    if (vendorID) {
        [apiProperties setValue:vendorID forKey:@"ios_idfv"];
    }

    if (_lastKnownLocation != nil) {
        @synchronized (_locationManager) {
            // Need to use NSInvocation because coordinate selector returns a C struct
            SEL coordinateSelector = NSSelectorFromString(@"coordinate");
            NSMethodSignature *coordinateMethodSignature = [_lastKnownLocation methodSignatureForSelector:coordinateSelector];
            NSInvocation *coordinateInvocation = [NSInvocation invocationWithMethodSignature:coordinateMethodSignature];
            [coordinateInvocation setTarget:_lastKnownLocation];
            [coordinateInvocation setSelector:coordinateSelector];
            [coordinateInvocation invoke];
            CLLocationCoordinate2D lastKnownLocationCoordinate;
            [coordinateInvocation getReturnValue:&lastKnownLocationCoordinate];

            [eventProperties setValue:[NSNumber numberWithDouble:lastKnownLocationCoordinate.latitude] forKey:@"_latitude"];
            [eventProperties setValue:[NSNumber numberWithDouble:lastKnownLocationCoordinate.longitude] forKey:@"_longitude"];
        }
    }
}

#pragma mark - logRevenue

// amount is a double in units of dollars
// ex. $3.99 would be passed as [NSNumber numberWithDouble:3.99]
- (void)logRevenue:(RakamRevenue *)revenue {
    if (_apiKey == nil) {
        RAKAM_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling logRevenue");
        return;
    }
    if (revenue == nil || ![revenue isValidRevenue]) {
        return;
    }

    [self logEvent:kRKMRevenueEvent withEventProperties:[revenue toNSDictionary]];
}

#pragma mark - Upload events

- (void)uploadEventsWithDelay:(int)delay {
    if (!_updateScheduled) {
        _updateScheduled = YES;
        __block __weak Rakam *weakSelf = self;
        [_backgroundQueue addOperationWithBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf performSelector:@selector(uploadEventsInBackground) withObject:nil afterDelay:delay];
            });
        }];
    }
}

- (void)uploadEventsInBackground {
    _updateScheduled = NO;
    [self uploadEvents];
}

- (void)uploadEvents {
    int limit = _backoffUpload ? _backoffUploadBatchSize : self.eventUploadMaxBatchSize;
    [self uploadEventsWithLimit:limit];
}

- (void)uploadEventsWithLimit:(int)limit {
    if (_apiKey == nil) {
        RAKAM_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before calling uploadEvents:");
        return;
    }

    @synchronized (self) {
        if (_updatingCurrently) {
            return;
        }
        _updatingCurrently = YES;
    }

    [self runOnBackgroundQueue:^{

        // Don't communicate with the server if the user has opted out.
        if ([self optOut] || _offline) {
            _updatingCurrently = NO;
            return;
        }

        long eventCount = [self.dbHelper getTotalEventCount];
        long numEvents = limit > 0 ? fminl(eventCount, limit) : eventCount;
        if (numEvents == 0) {
            _updatingCurrently = NO;
            return;
        }
        NSMutableArray *events = [self.dbHelper getEvents:-1 limit:numEvents];
        NSMutableArray *identifys = [self.dbHelper getIdentifys:-1 limit:numEvents];
        NSDictionary *merged = [self mergeEventsAndIdentifys:events identifys:identifys numEvents:numEvents];

        NSMutableArray *uploadEvents = [merged objectForKey:EVENTS];
        long long maxEventId = [[merged objectForKey:MAX_EVENT_ID] longLongValue];
        long long maxIdentifyId = [[merged objectForKey:MAX_IDENTIFY_ID] longLongValue];

        NSError *error = nil;
        NSData *eventsDataLocal = nil;
        eventsDataLocal = [NSJSONSerialization dataWithJSONObject:uploadEvents options:0 error:&error];
        if (error != nil) {
            RAKAM_ERROR(@"ERROR: NSJSONSerialization error: %@", error);
            _updatingCurrently = NO;
            return;
        }

        NSString *eventsString = [[NSString alloc] initWithData:eventsDataLocal encoding:NSUTF8StringEncoding];
        if ([RakamUtils isEmptyString:eventsString]) {
            RAKAM_ERROR(@"ERROR: JSONSerialization of event upload data resulted in a NULL string");
            if (eventsString != nil) {
                SAFE_ARC_RELEASE(eventsString);
            }
            _updatingCurrently = NO;
            return;
        }


        [self makeEventUploadPostRequest:_apiUrl events:eventsString numEvents:numEvents maxEventId:maxEventId maxIdentifyId:maxIdentifyId];
        SAFE_ARC_RELEASE(eventsString);
    }];
}

- (long long)getNextSequenceNumber {
    NSNumber *sequenceNumberFromDB = [self.dbHelper getLongValue:SEQUENCE_NUMBER];
    long long sequenceNumber = 0;
    if (sequenceNumberFromDB != nil) {
        sequenceNumber = [sequenceNumberFromDB longLongValue];
    }

    sequenceNumber++;
    [self.dbHelper insertOrReplaceKeyLongValue:SEQUENCE_NUMBER value:[NSNumber numberWithLongLong:sequenceNumber]];

    return sequenceNumber;
}

- (NSDictionary *)mergeEventsAndIdentifys:(NSMutableArray *)events identifys:(NSMutableArray *)identifys numEvents:(long)numEvents {
    NSMutableArray *mergedEvents = [[NSMutableArray alloc] init];
    long long maxEventId = -1;
    long long maxIdentifyId = -1;

    // NSArrays actually have O(1) performance for push/pop
    while ([mergedEvents count] < numEvents) {
        NSDictionary *event = nil;
        NSDictionary *identify = nil;

        BOOL noIdentifies = [identifys count] == 0;
        BOOL noEvents = [events count] == 0;

        // case 0: no events or identifies, should not happen - means less events / identifies than expected
        if (noEvents && noIdentifies) {
            break;
        }

        // case 1: no identifys grab from events
        if (noIdentifies) {
            event = SAFE_ARC_RETAIN(events[0]);
            [events removeObjectAtIndex:0];
            maxEventId = [[event objectForKey:@"event_id"] longValue];

            // case 2: no events grab from identifys
        } else if (noEvents) {
            identify = SAFE_ARC_RETAIN(identifys[0]);
            [identifys removeObjectAtIndex:0];
            maxIdentifyId = [[identify objectForKey:@"event_id"] longValue];

            // case 3: need to compare sequence numbers
        } else {
            // events logged before v3.2.0 won't have sequeunce number, put those first
            event = SAFE_ARC_RETAIN(events[0]);
            identify = SAFE_ARC_RETAIN(identifys[0]);
            if ([event objectForKey:SEQUENCE_NUMBER] == nil ||
                    ([[event objectForKey:SEQUENCE_NUMBER] longLongValue] <
                            [[identify objectForKey:SEQUENCE_NUMBER] longLongValue])) {
                [events removeObjectAtIndex:0];
                maxEventId = [[event objectForKey:EVENT_ID] longValue];
                SAFE_ARC_RELEASE(identify);
                identify = nil;
            } else {
                [identifys removeObjectAtIndex:0];
                maxIdentifyId = [[identify objectForKey:EVENT_ID] longValue];
                SAFE_ARC_RELEASE(event);
                event = nil;
            }
        }

        [mergedEvents addObject:event != nil ? event : identify];
        SAFE_ARC_RELEASE(event);
        SAFE_ARC_RELEASE(identify);
    }

    NSDictionary *results = [[NSDictionary alloc] initWithObjectsAndKeys:mergedEvents, EVENTS, [NSNumber numberWithLongLong:maxEventId], MAX_EVENT_ID, [NSNumber numberWithLongLong:maxIdentifyId], MAX_IDENTIFY_ID, nil];
    SAFE_ARC_RELEASE(mergedEvents);
    return SAFE_ARC_AUTORELEASE(results);
}

- (void)makeEventUploadPostRequest:(NSString *)url events:(NSString *)events numEvents:(long)numEvents maxEventId:(long long)maxEventId maxIdentifyId:(long long)maxIdentifyId {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    [request setTimeoutInterval:60.0];

    NSString *apiVersionString = [[NSNumber numberWithInt:kRKMApiVersion] stringValue];

    NSMutableData *postData = [[NSMutableData alloc] init];
    [postData appendData:[@"{\"api\":{" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"\"api_version\":\"" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[apiVersionString dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"\", \"api_key\":\"" dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[_apiKey dataUsingEncoding:NSUTF8StringEncoding]];

    // Add timestamp of upload
    [postData appendData:[@"\", \"upload_time\": \"" dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *timestampString = [[NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000] stringValue];
    [postData appendData:[timestampString dataUsingEncoding:NSUTF8StringEncoding]];

    // Add checksum
    [postData appendData:[@"\", \"checksum\": \"" dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *checksumData = [NSString stringWithFormat:@"%@%@%@%@", _apiKey, apiVersionString, timestampString, events];
    NSString *checksum = [self md5HexDigest:checksumData];
    [postData appendData:[checksum dataUsingEncoding:NSUTF8StringEncoding]];

    [postData appendData:[@"\"}, \"events\": " dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[events dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[@"}" dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long) [postData length]] forHTTPHeaderField:@"Content-Length"];

    [request setHTTPBody:postData];
    RAKAM_LOG(@"Events: %@", events);

    SAFE_ARC_RELEASE(postData);

    id Connection = [NSURLConnection class];
    [Connection sendAsynchronousRequest:request queue:_backgroundQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        BOOL uploadSuccessful = NO;
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        if (response != nil) {
            if ([httpResponse statusCode] == 200) {
                NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if ([result isEqualToString:@"1"]) {
                    // success, remove existing events from dictionary
                    uploadSuccessful = YES;
                    if (maxEventId >= 0) {
                        (void) [self.dbHelper removeEvents:maxEventId];
                    }
                    if (maxIdentifyId >= 0) {
                        (void) [self.dbHelper removeIdentifys:maxIdentifyId];
                    }
                } else if ([httpResponse statusCode] == 403) {
                    RAKAM_ERROR(@"ERROR: Invalid API Key, make sure your API key is correct in initializeApiKey:");
                } else if ([result isEqualToString:@"{\"error\":\"Checksum is invalid\",\"error_code\":400}"]) {
                    RAKAM_ERROR(@"ERROR: Bad checksum, post request was mangled in transit, will attempt to reupload later");
                } else {
                    RAKAM_ERROR(@"ERROR: %@, will attempt to reupload later", result);
                }
                SAFE_ARC_RELEASE(result);
            } else if ([httpResponse statusCode] == 413) {
                // If blocked by one massive event, drop it
                if (numEvents == 1) {
                    if (maxEventId >= 0) {
                        (void) [self.dbHelper removeEvent:maxEventId];
                    }
                    if (maxIdentifyId >= 0) {
                        (void) [self.dbHelper removeIdentifys:maxIdentifyId];
                    }
                }

                // server complained about length of request, backoff and try again
                _backoffUpload = YES;
                long newNumEvents = MIN(numEvents, _backoffUploadBatchSize);
                _backoffUploadBatchSize = MAX((int) ceilf(newNumEvents / 2.0f), 1);
                RAKAM_LOG(@"Request too large, will decrease size and attempt to reupload");
                _updatingCurrently = NO;
                [self uploadEventsWithLimit:_backoffUploadBatchSize];

            } else {
                RAKAM_ERROR(@"ERROR: Connection response received:%ld, %@", (long) [httpResponse statusCode],
                        SAFE_ARC_AUTORELEASE([[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]));
            }
        } else if (error != nil) {
            if ([error code] == -1009) {
                RAKAM_LOG(@"No internet connection (not connected to internet), unable to upload events");
            } else if ([error code] == -1003) {
                RAKAM_LOG(@"No internet connection (hostname not found), unable to upload events");
            } else if ([error code] == -1001) {
                RAKAM_LOG(@"No internet connection (request timed out), unable to upload events");
            } else {
                RAKAM_ERROR(@"ERROR: Connection error:%@", error);
            }
        } else {
            RAKAM_ERROR(@"ERROR: response empty, error empty for NSURLConnection");
        }

        _updatingCurrently = NO;

        if (uploadSuccessful && [self.dbHelper getEventCount] > self.eventUploadThreshold) {
            int limit = _backoffUpload ? _backoffUploadBatchSize : 0;
            [self uploadEventsWithLimit:limit];

        } else if (_uploadTaskID != UIBackgroundTaskInvalid) {
            if (uploadSuccessful) {
                _backoffUpload = NO;
                _backoffUploadBatchSize = self.eventUploadMaxBatchSize;
            }

            // Upload finished, allow background task to be ended
            UIApplication *app = [self getSharedApplication];
            if (app != nil) {
                [app endBackgroundTask:_uploadTaskID];
                _uploadTaskID = UIBackgroundTaskInvalid;
            }
        }
    }];
}

#pragma mark - application lifecycle methods

- (void)enterForeground {
    UIApplication *app = [self getSharedApplication];
    if (app == nil) {
        return;
    }

    [self updateLocation];

    NSNumber *now = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];

    // Stop uploading
    if (_uploadTaskID != UIBackgroundTaskInvalid) {
        [app endBackgroundTask:_uploadTaskID];
        _uploadTaskID = UIBackgroundTaskInvalid;
    }
    [self runOnBackgroundQueue:^{
        [self startOrContinueSession:now];
        _inForeground = YES;
        [self uploadEvents];
    }];
}

- (void)enterBackground {
    UIApplication *app = [self getSharedApplication];
    if (app == nil) {
        return;
    }

    NSNumber *now = [NSNumber numberWithLongLong:[[self currentTime] timeIntervalSince1970] * 1000];

    // Stop uploading
    if (_uploadTaskID != UIBackgroundTaskInvalid) {
        [app endBackgroundTask:_uploadTaskID];
    }
    _uploadTaskID = [app beginBackgroundTaskWithExpirationHandler:^{
        //Took too long, manually stop
        if (_uploadTaskID != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:_uploadTaskID];
            _uploadTaskID = UIBackgroundTaskInvalid;
        }
    }];
    [self runOnBackgroundQueue:^{
        _inForeground = NO;
        [self refreshSessionTime:now];
        [self uploadEventsWithLimit:0];
    }];
}

#pragma mark - Sessions

/**
 * Creates a new session if we are in the background and
 * the current session is expired or if there is no current session ID].
 * Otherwise extends the session.
 *
 * Returns YES if a new session was created.
 */
- (BOOL)startOrContinueSession:(NSNumber *)timestamp {
    if (!_inForeground) {
        if ([self inSession]) {
            if ([self isWithinMinTimeBetweenSessions:timestamp]) {
                [self refreshSessionTime:timestamp];
                return NO;
            }
            [self startNewSession:timestamp];
            return YES;
        }
        // no current session, check for previous session
        if ([self isWithinMinTimeBetweenSessions:timestamp]) {
            // extract session id
            long long previousSessionId = [self previousSessionId];
            if (previousSessionId == -1) {
                [self startNewSession:timestamp];
                return YES;
            }
            // extend previous session
            [self setSessionId:previousSessionId];
            [self refreshSessionTime:timestamp];
            return NO;
        } else {
            [self startNewSession:timestamp];
            return YES;
        }
    }
    // not creating a session means we should continue the session
    [self refreshSessionTime:timestamp];
    return NO;
}

- (void)startNewSession:(NSNumber *)timestamp {
    if (_trackingSessionEvents) {
        [self sendSessionEvent:kRKMSessionEndEvent];
    }
    [self setSessionId:[timestamp longLongValue]];
    [self refreshSessionTime:timestamp];
    if (_trackingSessionEvents) {
        [self sendSessionEvent:kRKMSessionStartEvent];
    }
}

- (void)sendSessionEvent:(NSString *)sessionEvent {
    if (_apiKey == nil) {
        RAKAM_ERROR(@"ERROR: apiKey cannot be nil or empty, set apiKey with initializeApiKey: before sending session event");
        return;
    }

    if (![self inSession]) {
        return;
    }

    NSMutableDictionary *apiProperties = [NSMutableDictionary dictionary];
    [apiProperties setValue:sessionEvent forKey:@"special"];
    NSNumber *timestamp = [self lastEventTime];
    [self logEvent:sessionEvent withEventProperties:nil withUserProperties:nil withGroups:nil withTimestamp:timestamp outOfSession:NO];
}

- (BOOL)inSession {
    return _sessionId >= 0;
}

- (BOOL)isWithinMinTimeBetweenSessions:(NSNumber *)timestamp {
    NSNumber *previousSessionTime = [self lastEventTime];
    long long timeDelta = [timestamp longLongValue] - [previousSessionTime longLongValue];

    return timeDelta < self.minTimeBetweenSessionsMillis;
}

/**
 * Sets the session ID in memory and persists it to disk.
 */
- (void)setSessionId:(long long)timestamp {
    _sessionId = timestamp;
    [self setPreviousSessionId:_sessionId];
}

/**
 * Update the session timer if there's a running session.
 */
- (void)refreshSessionTime:(NSNumber *)timestamp {
    if (![self inSession]) {
        return;
    }
    [self setLastEventTime:timestamp];
}

- (void)setPreviousSessionId:(long long)previousSessionId {
    NSNumber *value = [NSNumber numberWithLongLong:previousSessionId];
    (void) [self.dbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_ID value:value];
}

- (long long)previousSessionId {
    NSNumber *previousSessionId = [self.dbHelper getLongValue:PREVIOUS_SESSION_ID];
    if (previousSessionId == nil) {
        return -1;
    }
    return [previousSessionId longLongValue];
}

- (void)setLastEventTime:(NSNumber *)timestamp {
    (void) [self.dbHelper insertOrReplaceKeyLongValue:PREVIOUS_SESSION_TIME value:timestamp];
}

- (NSNumber *)lastEventTime {
    return [self.dbHelper getLongValue:PREVIOUS_SESSION_TIME];
}

- (void)startSession {
    return;
}

- (void)identify:(RakamIdentify *)identify {
    [self identify:identify outOfSession:NO];
}

- (void)identify:(RakamIdentify *)identify outOfSession:(BOOL)outOfSession {
    if (identify == nil || [identify.userPropertyOperations count] == 0) {
        return;
    }
    [self logEvent:IDENTIFY_EVENT withEventProperties:nil withUserProperties:identify.userPropertyOperations withGroups:nil withTimestamp:nil outOfSession:outOfSession];
}

#pragma mark - configurations

- (void)setUserProperties:(NSDictionary *)userProperties {
    if (userProperties == nil || ![self isArgument:userProperties validType:[NSDictionary class] methodName:@"setUserProperties:"] || [userProperties count] == 0) {
        return;
    }

    NSDictionary *copy = [userProperties copy];
    [self runOnBackgroundQueue:^{
        // sanitize and truncate user properties before turning into identify
        NSDictionary *sanitized = [self truncate:copy];
        if ([sanitized count] == 0) {
            return;
        }

        RakamIdentify *identify = [RakamIdentify identify];
        for (NSString *key in copy) {
            NSObject *value = [copy objectForKey:key];
            [identify set:key value:value];
        }
        [self identify:identify];
    }];
}

- (void)clearUserProperties {
    RakamIdentify *identify = [[RakamIdentify identify] clearAll];
    [self identify:identify];
}

- (void)setUserId:(NSString *)userId {
    if (!(userId == nil || [self isArgument:userId validType:[NSString class] methodName:@"setUserId:"])) {
        return;
    }

    [self runOnBackgroundQueue:^{
        (void) SAFE_ARC_RETAIN(userId);
        SAFE_ARC_RELEASE(_userId);
        _userId = userId;
        (void) [self.dbHelper insertOrReplaceKeyValue:USER_ID value:_userId];
    }];
}

- (void)setOptOut:(BOOL)enabled {
    [self runOnBackgroundQueue:^{
        NSNumber *value = [NSNumber numberWithBool:enabled];
        (void) [self.dbHelper insertOrReplaceKeyLongValue:OPT_OUT value:value];
    }];
}

- (void)setOffline:(BOOL)offline {
    _offline = offline;

    if (!_offline) {
        [self uploadEvents];
    }
}

- (void)setEventUploadMaxBatchSize:(int)eventUploadMaxBatchSize {
    _eventUploadMaxBatchSize = eventUploadMaxBatchSize;
    _backoffUploadBatchSize = eventUploadMaxBatchSize;
}

- (BOOL)optOut {
    return [[self.dbHelper getLongValue:OPT_OUT] boolValue];
}

- (void)setDeviceId:(NSString *)deviceId {
    if (![self isValidDeviceId:deviceId]) {
        return;
    }

    [self runOnBackgroundQueue:^{
        (void) SAFE_ARC_RETAIN(deviceId);
        SAFE_ARC_RELEASE(_deviceId);
        _deviceId = deviceId;
        (void) [self.dbHelper insertOrReplaceKeyValue:DEVICE_ID value:deviceId];
    }];
}

- (void)regenerateDeviceId {
    [self runOnBackgroundQueue:^{
        [self setDeviceId:[RakamDeviceInfo generateUUID]];
    }];
}

#pragma mark - location methods

- (void)updateLocation {
    if (_locationListeningEnabled) {
        CLLocation *location = [_locationManager location];
        @synchronized (_locationManager) {
            if (location != nil) {
                (void) SAFE_ARC_RETAIN(location);
                SAFE_ARC_RELEASE(_lastKnownLocation);
                _lastKnownLocation = location;
            }
        }
    }
}

- (void)enableLocationListening {
    _locationListeningEnabled = YES;
    [self updateLocation];
}

- (void)disableLocationListening {
    _locationListeningEnabled = NO;
}

- (void)useAdvertisingIdForDeviceId {
    _useAdvertisingIdForDeviceId = YES;
}

#pragma mark - Getters for device data

- (NSString *)getDeviceId {
    return _deviceId;
}

- (long long)getSessionId {
    return _sessionId;
}

- (NSString *)initializeDeviceId {
    if (_deviceId == nil) {
        _deviceId = SAFE_ARC_RETAIN([self.dbHelper getValue:DEVICE_ID]);
        if (![self isValidDeviceId:_deviceId]) {
            NSString *newDeviceId = SAFE_ARC_RETAIN([self _getDeviceId]);
            SAFE_ARC_RELEASE(_deviceId);
            _deviceId = newDeviceId;
            (void) [self.dbHelper insertOrReplaceKeyValue:DEVICE_ID value:newDeviceId];
        }
    }
    return _deviceId;
}

- (NSString *)_getDeviceId {
    NSString *deviceId = nil;
    if (_useAdvertisingIdForDeviceId) {
        deviceId = _deviceInfo.advertiserID;
    }

    // return identifierForVendor
    if (!deviceId) {
        deviceId = _deviceInfo.vendorID;
    }

    if (!deviceId) {
        // Otherwise generate random ID
        deviceId = [RakamDeviceInfo generateUUID];
    }
    return SAFE_ARC_AUTORELEASE([[NSString alloc] initWithString:deviceId]);
}

- (BOOL)isValidDeviceId:(NSString *)deviceId {
    if (deviceId == nil ||
            ![self isArgument:deviceId validType:[NSString class] methodName:@"isValidDeviceId"] ||
            [deviceId isEqualToString:@"e3f5536a141811db40efd6400f1d0a4e"] ||
            [deviceId isEqualToString:@"04bab7ee75b9a58d39b8dc54e8851084"]) {
        return NO;
    }
    return YES;
}

- (NSDictionary *)replaceWithEmptyJSON:(NSDictionary *)dictionary {
    return dictionary == nil ? [NSMutableDictionary dictionary] : dictionary;
}

- (id)truncate:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        obj = (NSString *) obj;
        if ([obj length] > kRKMMaxStringLength) {
            obj = [obj substringToIndex:kRKMMaxStringLength];
        }
    } else if ([obj isKindOfClass:[NSArray class]]) {
        NSMutableArray *arr = [NSMutableArray array];
        id objCopy = [obj copy];
        for (id i in objCopy) {
            [arr addObject:[self truncate:i]];
        }
        SAFE_ARC_RELEASE(objCopy);
        obj = [NSArray arrayWithArray:arr];
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        // if too many properties, ignore
        if ([(NSDictionary *) obj count] > kRKMMaxPropertyKeys) {
            RAKAM_LOG(@"WARNING: too many properties (more than 1000), ignoring");
            return [NSDictionary dictionary];
        }

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        id objCopy = [obj copy];
        for (id key in objCopy) {
            NSString *coercedKey;
            if (![key isKindOfClass:[NSString class]]) {
                coercedKey = [key description];
                RAKAM_LOG(@"WARNING: Non-string property key, received %@, coercing to %@", [key class], coercedKey);
            } else {
                coercedKey = key;
            }
            // do not truncate revenue receipt field
            if ([coercedKey isEqualToString:RKM_REVENUE_RECEIPT]) {
                dict[coercedKey] = objCopy[key];
            } else {
                dict[coercedKey] = [self truncate:objCopy[key]];
            }
        }
        SAFE_ARC_RELEASE(objCopy);
        obj = [NSDictionary dictionaryWithDictionary:dict];
    }
    return obj;
}

- (BOOL)isArgument:(id)argument validType:(Class)class methodName:(NSString *)methodName {
    if ([argument isKindOfClass:class]) {
        return YES;
    } else {
        RAKAM_ERROR(@"ERROR: Invalid type argument to method %@, expected %@, received %@, ", methodName, class, [argument class]);
        return NO;
    }
}

- (NSString *)md5HexDigest:(NSString *)input {
    const char *str = [input UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG) strlen(str), result);

    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x", result[i]];
    }
    return ret;
}

- (NSString *)urlEncodeString:(NSString *)string {
    NSString *newString;
#if __has_feature(objc_arc)
    newString = (__bridge_transfer NSString *)
            CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                    (__bridge CFStringRef) string,
                    NULL,
                    CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
                    CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
#else
    newString = NSMakeCollectable(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
            (CFStringRef) string,
            NULL,
            CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"),
            CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding)));
    SAFE_ARC_AUTORELEASE(newString);
#endif
    if (newString) {
        return newString;
    }
    return @"";
}

- (NSDate *)currentTime {
    return [NSDate date];
}

- (void)printEventsCount {
    RAKAM_LOG(@"Events count:%ld", (long) [self.dbHelper getEventCount]);
}

#pragma mark - Compatibility


/**
 * Move all preference data from the legacy name to the new, static name if needed.
 *
 * Data used to be in the NSCachesDirectory, which would sometimes be cleared unexpectedly,
 * resulting in data loss. We move the data from NSCachesDirectory to the current
 * location in NSLibraryDirectory.
 *
 */
- (BOOL)upgradePrefs {
    // Copy any old data files to new file paths
    NSString *oldEventsDataDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *oldPropertyListPath = [oldEventsDataDirectory stringByAppendingPathComponent:@"io.rakam.plist"];
    NSString *oldEventsDataPath = [oldEventsDataDirectory stringByAppendingPathComponent:@"io.rakam.archiveDict"];
    BOOL success = [self moveFileIfNotExists:oldPropertyListPath to:_propertyListPath];
    success &= [self moveFileIfNotExists:oldEventsDataPath to:_eventsDataPath];
    return success;
}

#pragma mark - Filesystem

- (BOOL)savePropertyList {
    @synchronized (_propertyList) {
        BOOL success = [self serializePList:_propertyList toFile:_propertyListPath];
        if (!success) {
            RAKAM_ERROR(@"Error: Unable to save propertyList to file");
        }
        return success;
    }
}

- (id)deserializePList:(NSString *)path {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSData *pListData = [[NSFileManager defaultManager] contentsAtPath:path];
        if (pListData != nil) {
            NSError *error = nil;
            NSMutableDictionary *pList = (NSMutableDictionary *) [NSPropertyListSerialization
                    propertyListWithData:pListData
                                 options:NSPropertyListMutableContainersAndLeaves
                                  format:NULL error:&error];
            if (error == nil) {
                return pList;
            } else {
                RAKAM_ERROR(@"ERROR: propertyList deserialization error:%@", error);
                error = nil;
                [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
                if (error != nil) {
                    RAKAM_ERROR(@"ERROR: Can't remove corrupt propertyList file:%@", error);
                }
            }
        }
    }
    return nil;
}

- (BOOL)serializePList:(id)data toFile:(NSString *)path {
    NSError *error = nil;
    NSData *propertyListData = [NSPropertyListSerialization
            dataWithPropertyList:data
                          format:NSPropertyListXMLFormat_v1_0
                         options:0 error:&error];
    if (error == nil) {
        if (propertyListData != nil) {
            BOOL success = [propertyListData writeToFile:path atomically:YES];
            if (!success) {
                RAKAM_ERROR(@"ERROR: Unable to save propertyList to file");
            }
            return success;
        } else {
            RAKAM_ERROR(@"ERROR: propertyListData is nil");
        }
    } else {
        RAKAM_ERROR(@"ERROR: Unable to serialize propertyList:%@", error);
    }
    return NO;

}

- (id)unarchive:(NSString *)path {
    // unarchive using new NSKeyedUnarchiver method from iOS 9.0 that doesn't throw exceptions
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_8_4) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if ([fileManager fileExistsAtPath:path]) {
            NSData *inputData = [fileManager contentsAtPath:path];
            NSError *error = nil;
            if (inputData != nil) {
                id data = [NSKeyedUnarchiver unarchiveTopLevelObjectWithData:inputData error:&error];
                if (error == nil) {
                    if (data != nil) {
                        return data;
                    } else {
                        RAKAM_ERROR(@"ERROR: unarchived data is nil for file: %@", path);
                    }
                } else {
                    RAKAM_ERROR(@"ERROR: Unable to unarchive file %@: %@", path, error);
                }
            } else {
                RAKAM_ERROR(@"ERROR: File data is nil for file: %@", path);
            }

            // if reach here, then an error occured during unarchiving, delete corrupt file
            [fileManager removeItemAtPath:path error:&error];
            if (error != nil) {
                RAKAM_ERROR(@"ERROR: Can't remove corrupt file %@: %@", path, error);
            }
        }
    } else {
        RAKAM_LOG(@"WARNING: user is using a version of iOS that is older than 9.0, skipping unarchiving of file: %@", path);
    }
    return nil;
}

- (BOOL)archive:(id)obj toFile:(NSString *)path {
    return [NSKeyedArchiver archiveRootObject:obj toFile:path];
}

- (BOOL)moveFileIfNotExists:(NSString *)from to:(NSString *)to {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    if (![fileManager fileExistsAtPath:to] &&
            [fileManager fileExistsAtPath:from]) {
        if ([fileManager copyItemAtPath:from toPath:to error:&error]) {
            RAKAM_LOG(@"INFO: copied %@ to %@", from, to);
            [fileManager removeItemAtPath:from error:NULL];
        } else {
            RAKAM_LOG(@"WARN: Copy from %@ to %@ failed: %@", from, to, error);
            return NO;
        }
    }
    return YES;
}

#pragma clang diagnostic pop
@end
