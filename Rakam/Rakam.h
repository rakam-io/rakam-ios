//
// Rakam.h

#import <Foundation/Foundation.h>
#import "RakamIdentify.h"
#import "RakamRevenue.h"


/**
 Rakam iOS SDK.

 Use the Rakam SDK to track events in your application.

 Setup:

 1. In every file that uses analytics, import Rakam.h at the top `#import "Rakam.h"`
 2. Be sure to initialize the API in your didFinishLaunchingWithOptions delegate `[[Rakam instance] initializeApiKey:[NSURL URLWithString:@"https://app.rakam.io"] : @"YOUR_API_KEY_HERE"];`
 3. Track an event anywhere in the app `[[Rakam instance] logEvent:@"EVENT_IDENTIFIER_HERE"];`
 4. You can attach additional data to any event by passing a NSDictionary object:

        NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
        [eventProperties setValue:@"VALUE_GOES_HERE" forKey:@"KEY_GOES_HERE"];
        [[Rakam instance] logEvent:@"Compute Hash" withEventProperties:eventProperties];

 **Note:** you should call SDK methods on an Rakam instance, for example logging events with the default instance: `[[Rakam instance] logEvent:@"testEvent"];`

 **Note:** the SDK supports tracking data to multiple Rakam apps, via separate named instances. For example: `[[Rakam instanceWithName:@"app1"] logEvent:@"testEvent"];` See [Tracking Events to Multiple Apps](https://github.com/rakam-io/rakam-ios#tracking-events-to-multiple-rakam-apps).

 For more details on the setup and usage, be sure to checkout the [README](https://github.com/rakam-io/rakam-ios)
 */
@interface Rakam : NSObject

#pragma mark - Properties

/**-----------------------------------------------------------------------------
* @name Instance Properties
* -----------------------------------------------------------------------------
*/

/**
 API key for your Rakam App.
 */
@property(nonatomic, strong, readonly) NSString *apiKey;
@property(nonatomic, strong, readonly) NSString *apiUrl;

/**
 Identifier for the current user.
 */
@property(nonatomic, strong, readonly) NSString *userId;

/**
 Identifier for the current device.
 */
@property(nonatomic, strong, readonly) NSString *deviceId;

/**
 Name of the SDK instance (ex: no name for default instance, or custom name for a named instance)
 */
@property(nonatomic, strong, readonly) NSString *instanceName;
@property(nonatomic, strong, readonly) NSString *propertyListPath;

/**
 Whether or to opt the current user out of tracking. If true then this blocks the logging of any events and properties, and blocks the sending of events to Rakam servers.
 */
@property(nonatomic, assign) BOOL optOut;


/**-----------------------------------------------------------------------------
 * @name Configurable SDK thresholds and parameters
 * -----------------------------------------------------------------------------
 */

/**
 The maximum number of events that can be stored locally before forcing an upload. The default is 30 events.
 */
@property(nonatomic, assign) int eventUploadThreshold;

/**
 The maximum number of events that can be uploaded in a single request. The default is 100 events.
 */
@property(nonatomic, assign) int eventUploadMaxBatchSize;

/**
 The maximum number of events that can be stored lcoally. The default is 1000 events.
 */
@property(nonatomic, assign) int eventMaxCount;

/**
 The amount of time after an event is logged that events will be batched before being uploaded to the server. The default is 30 seconds.
 */
@property(nonatomic, assign) int eventUploadPeriodSeconds;

/**
 When a user closes and reopens the app within minTimeBetweenSessionsMillis milliseconds, the reopen is considered part of the same session and the session continues. Otherwise, a new session is created. The default is 15 minutes.
 */
@property(nonatomic, assign) long minTimeBetweenSessionsMillis;

/**
 Whether to automatically log start and end session events corresponding to the start and end of a user's session.
 */
@property(nonatomic, assign) BOOL trackingSessionEvents;


#pragma mark - Methods

/**-----------------------------------------------------------------------------
 * @name Fetching Rakam SDK instance
 * -----------------------------------------------------------------------------
 */

/**
 This fetches the default SDK instance. Recommended if you are only logging events to a single app.

 @returns the default Rakam SDK instance
 */
+ (Rakam *)instance;

/**
 This fetches a named SDK instance. Use this if logging events to multiple Rakam apps.

 @param instanceName the name of the SDK instance to fetch.

 @returns the Rakam SDK instance corresponding to `instanceName`

 @see [Tracking Events to Multiple Rakam Apps](https://github.com/rakam-io/rakam-ios#tracking-events-to-multiple-rakam-apps)
 */
+ (Rakam *)instanceWithName:(NSString *)instanceName;

/**-----------------------------------------------------------------------------
 * @name Initialize the Rakam SDK with your Rakam API Key
 * -----------------------------------------------------------------------------
 */

/**
 Initializes the Rakam instance with your Rakam API key

 We recommend you first initialize your class within your "didFinishLaunchingWithOptions" method inside your app delegate.

 **Note:** this is required before you can log any events.

 @param apiKey Your Rakam key obtained from your dashboard at https://rakam.io/settings
 */
- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey;

/**
 Initializes the Rakam instance with your Rakam API key and sets a user identifier for the current user.

 We recommend you first initialize your class within your "didFinishLaunchingWithOptions" method inside your app delegate.

 **Note:** this is required before you can log any events.

 @param apiKey Your Rakam key obtained from your dashboard at https://rakam.io/settings

 @param userId If your app has its own login system that you want to track users with, you can set the userId.

*/
- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId;


/**-----------------------------------------------------------------------------
 * @name Logging Events
 * -----------------------------------------------------------------------------
 */

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)
 */
- (void)logEvent:(NSString *)eventType;

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.
 @param eventProperties          You can attach additional data to any event by passing a NSDictionary object with property: value pairs.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)
 */
- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties;

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.
 @param eventProperties          You can attach additional data to any event by passing a NSDictionary object with property: value pairs.
 @param outOfSession             If YES, will track the event as out of session. Useful for push notification events.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)
 @see [Tracking Sessions](https://github.com/rakam-io/rakam-ios#tracking-sessions)
 */
- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties outOfSession:(BOOL)outOfSession;

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.
 @param eventProperties          You can attach additional data to any event by passing a NSDictionary object with property: value pairs.
 @param groups                   You can specify event-level groups for this user by passing a NSDictionary object with groupType: groupName pairs. Note the keys need to be strings, and the values can either be strings or an array of strings.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)

 @see [Setting Groups](https://github.com/rakam-io/rakam-ios#setting-groups)
 */
- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups;

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.
 @param eventProperties          You can attach additional data to any event by passing a NSDictionary object with property: value pairs.
 @param groups                   You can specify event-level groups for this user by passing a NSDictionary object with groupType: groupName pairs. Note the keys need to be strings, and the values can either be strings or an array of strings.
 @param outOfSession             If YES, will track the event as out of session. Useful for push notification events.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)

 @see [Setting Groups](https://github.com/rakam-io/rakam-ios#setting-groups)

 @see [Tracking Sessions](https://github.com/rakam-io/rakam-ios#tracking-sessions)
 */
- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups outOfSession:(BOOL)outOfSession;

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.
 @param eventProperties          You can attach additional data to any event by passing a NSDictionary object with property: value pairs.
 @param groups                   You can specify event-level groups for this user by passing a NSDictionary object with groupType: groupName pairs. Note the keys need to be strings, and the values can either be strings or an array of strings.
 @param longLongTimestamp        You can specify a custom timestamp by passing the milliseconds since epoch UTC time as a long long.
 @param outOfSession             If YES, will track the event as out of session. Useful for push notification events.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)

 @see [Setting Groups](https://github.com/rakam-io/rakam-ios#setting-groups)

 @see [Tracking Sessions](https://github.com/rakam-io/rakam-ios#tracking-sessions)
 */
- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups withLongLongTimestamp:(long long)longLongTimestamp outOfSession:(BOOL)outOfSession;

/**
 Tracks an event. Events are saved locally.

 Uploads are batched to occur every 30 events or every 30 seconds (whichever comes first), as well as on app close.

 @param eventType                The name of the event you wish to track.
 @param eventProperties          You can attach additional data to any event by passing a NSDictionary object with property: value pairs.
 @param groups                   You can specify event-level groups for this user by passing a NSDictionary object with groupType: groupName pairs. Note the keys need to be strings, and the values can either be strings or an array of strings.
 @param timestamp                You can specify a custom timestamp by passing an NSNumber representing the milliseconds since epoch UTC time. We recommend using [NSNumber numberWithLongLong:milliseconds] to create the value. If nil is passed in, then the event will be timestamped with the current time.
 @param outOfSession             If YES, will track the event as out of session. Useful for push notification events.

 @see [Tracking Events](https://github.com/rakam-io/rakam-ios#tracking-events)

 @see [Setting Groups](https://github.com/rakam-io/rakam-ios#setting-groups)

 @see [Tracking Sessions](https://github.com/rakam-io/rakam-ios#tracking-sessions)
 */
- (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties withGroups:(NSDictionary *)groups withTimestamp:(NSNumber *)timestamp outOfSession:(BOOL)outOfSession;

/**-----------------------------------------------------------------------------
 * @name Logging Revenue
 * -----------------------------------------------------------------------------
 */

/**
 Tracks revenue - API v2. This uses the `RKMRevenue` object to store transaction properties such as quantity, price, and revenue type. This is the recommended method for tracking revenue in Rakam.

 For validating revenue, make sure the receipt data is set on the RKMRevenue object.

 To track revenue from a user, create an RKMRevenue object each time the user generates revenue, and set the revenue properties (productIdentifier, price, quantity). logRevenue: takes in an RKMRevenue object. This allows us to automatically display data relevant to revenue on the Rakam website, including average revenue per daily active user (ARPDAU), 7, 30, and 90 day revenue, lifetime value (LTV) estimates, and revenue by advertising campaign cohort and daily/weekly/monthly cohorts.

 @param revenue RKMRevenue object       revenue object contains all revenue information

 @see [Tracking Revenue](https://github.com/rakam-io/rakam-ios#tracking-revenue)
 */
- (void)logRevenue:(RakamRevenue *)revenue;

/**-----------------------------------------------------------------------------
 * @name User Properties and User Property Operations
 * -----------------------------------------------------------------------------
 */

/**
 Update user properties using operations provided via Identify API.

 To update user properties, first create an RKMIdentify object. For example if you wanted to set a user's gender, and then increment their karma count by 1, you would do:

    RKMIdentify *identify = [[[RKMIdentify identify] set:@"gender" value:@"male"] add:@"karma" value:[NSNumber numberWithInt:1]];

 Then you would pass this RKMIdentify object to the identify function to send to the server:

    [[Rakam instance] identify:identify];

 @param identify                   An RKMIdentify object with the intended user property operations

 @see [User Properties and User Property Operations](https://github.com/rakam-io/rakam-ios#user-properties-and-user-property-operations)

 */

- (void)identify:(RakamIdentify *)identify;

/**
 Update user properties using operations provided via Identify API. If outOfSession is `YES` then the identify event is logged with a session id of -1 and does not trigger any session-handling logic.

 To update user properties, first create an RKMIdentify object. For example if you wanted to set a user's gender, and then increment their karma count by 1, you would do:

 RKMIdentify *identify = [[[RKMIdentify identify] set:@"gender" value:@"male"] add:@"karma" value:[NSNumber numberWithInt:1]];

 Then you would pass this RKMIdentify object to the identify function to send to the server:

 [[Rakam instance] identify:identify outOfSession:YES];

 @param identify                   An RKMIdentify object with the intended user property operations
 @param outOfSession               Whether to log identify event out of session

 @see [User Properties and User Property Operations](https://github.com/rakam-io/rakam-ios#user-properties-and-user-property-operations)

 */

- (void)identify:(RakamIdentify *)identify outOfSession:(BOOL)outOfSession;

/**

 Adds properties that are tracked on the user level.

 **Note:** Property keys must be <code>NSString</code> objects and values must be serializable.

 @param userProperties          An NSDictionary containing any additional data to be tracked.

 @see [Setting Multiple Properties with setUserProperties](https://github.com/rakam-io/rakam-ios#setting-multiple-properties-with-setuserproperties)
 */
- (void)setUserProperties:(NSDictionary *)userProperties;

/**
 Clears all properties that are tracked on the user level.

 **Note: the result is irreversible!**

 @see [Clearing user properties](https://github.com/rakam-io/rakam-ios#clearing-user-properties-with-clearuserproperties)
 */

- (void)clearUserProperties;

/**-----------------------------------------------------------------------------
 * @name Setting User and Device Identifiers
 * -----------------------------------------------------------------------------
 */

/**
 Sets the userId.

 @param userId                  If your app has its own login system that you want to track users with, you can set the userId.

 @see [Setting Custom UserIds](https://github.com/rakam-io/rakam-ios#setting-custom-user-ids)
 */
- (void)setUserId:(NSString *)userId;

/**
 Sets the deviceId.

 **NOTE: not recommended unless you know what you are doing**

 @param deviceId                  If your app has its own system for tracking devices, you can set the deviceId.

 @see [Setting Custom Device Ids](https://github.com/rakam-io/rakam-ios#custom-device-ids)
 */
- (void)setDeviceId:(NSString *)deviceId;

/**-----------------------------------------------------------------------------
 * @name Configuring the SDK instance
 * -----------------------------------------------------------------------------
 */

/**
 Enables tracking opt out.

 If the user wants to opt out of all tracking, use this method to enable opt out for them. Once opt out is enabled, no events will be saved locally or sent to the server. Calling this method again with enabled set to NO will turn tracking back on for the user.

 @param enabled                  Whether tracking opt out should be enabled or disabled.
 */
- (void)setOptOut:(BOOL)enabled;

/**
 Disables sending logged events to Rakam servers.

 If you want to stop logged events from being sent to Rakam severs, use this method to set the client to offline. Once offline is enabled, logged events will not be sent to the server until offline is disabled. Calling this method again with offline set to NO will allow events to be sent to server and the client will attempt to send events that have been queued while offline.

 @param offline                  Whether logged events should be sent to Rakam servers.
 */
- (void)setOffline:(BOOL)offline;

/**
 Enables location tracking.

 If the user has granted your app location permissions, the SDK will also grab the location of the user. Rakam will never prompt the user for location permissions itself, this must be done by your app.

 **Note:** the user's location is only fetched once per session. Use `updateLocation` to force the SDK to fetch the user's latest location.
 */
- (void)enableLocationListening;

/**
 Disables location tracking. If you want location tracking disabled on startup of the app, call disableLocationListening before you call initializeApiKey.
 */
- (void)disableLocationListening;

/**
 Forces the SDK to update with the user's last known location if possible.

 If you want to manually force the SDK to update with the user's last known location, call updateLocation.
 */
- (void)updateLocation;

/**
 Uses advertisingIdentifier instead of identifierForVendor as the device ID

 Apple prohibits the use of advertisingIdentifier if your app does not have advertising. Useful for tying together data from advertising campaigns to anlaytics data.

 **NOTE:** Must be called before initializeApiKey: is called to function.
 */
- (void)useAdvertisingIdForDeviceId;

/**-----------------------------------------------------------------------------
 * @name Other Methods
 * -----------------------------------------------------------------------------
 */

/**
 Prints the number of events in the queue.

 Debugging method to find out how many events are being stored locally on the device.
 */
- (void)printEventsCount;

/**
 Fetches the deviceId, a unique identifier shared between multiple users using the same app on the same device.

 @returns the deviceId.
 */
- (NSString *)getDeviceId;

/**
 Regenerates a new random deviceId for current user. Note: this is not recommended unless you know what you are doing. This can be used in conjunction with setUserId:nil to anonymize users after they log out. With a nil userId and a completely new deviceId, the current user would appear as a brand new user in dashboard.

 @see [Logging Out Users](https://github.com/rakam-io/rakam-ios#logging-out-and-anonymous-users)
 */
- (void)regenerateDeviceId;

/**
 Fetches the current sessionId, an identifier used by Rakam to group together events tracked during the same session.

 @returns the current session id

 @see [Tracking Sessions](https://github.com/rakam-io/rakam-ios#tracking-sessions)
 */
- (long long)getSessionId;

/**
 Manually forces the instance to immediately upload all unsent events.

 Events are saved locally. Uploads are batched to occur every 30 events and every 30 seconds, as well as on app close. Use this method to force the class to immediately upload all queued events.
 */
- (void)uploadEvents;


#pragma mark - Deprecated methods

- (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId startSession:(BOOL)startSession __attribute((deprecated()));

- (void)startSession __attribute((deprecated()));

+ (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey __attribute((deprecated()));

+ (void)initializeApiKey:(NSURL *)apiUrl :(NSString *)apiKey userId:(NSString *)userId __attribute((deprecated()));

+ (void)logEvent:(NSString *)eventType __attribute((deprecated()));

+ (void)logEvent:(NSString *)eventType withEventProperties:(NSDictionary *)eventProperties __attribute((deprecated()));

+ (void)uploadEvents __attribute((deprecated()));

+ (void)setUserProperties:(NSDictionary *)userProperties __attribute((deprecated()));

+ (void)setUserId:(NSString *)userId __attribute((deprecated()));

+ (void)enableLocationListening __attribute((deprecated()));

+ (void)disableLocationListening __attribute((deprecated()));

+ (void)useAdvertisingIdForDeviceId __attribute((deprecated()));

+ (void)printEventsCount __attribute((deprecated()));

+ (NSString *)getDeviceId __attribute((deprecated()));
@end

#pragma mark - constants

extern NSString *const kRKMSessionStartEvent;
extern NSString *const kRKMSessionEndEvent;
extern NSString *const kRKMRevenueEvent;
