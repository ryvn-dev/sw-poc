#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

/// Unified contact event callback, fired on the main queue.
///
/// The `_type` key distinguishes events:
///
/// "peer_found"  — first advertisement from a new peer
///   keys: name(NSString), mbti(NSString), rssi(NSNumber), distance(NSString)
///
/// "peer_update" — repeated advertisement from an active peer
///   keys: name, mbti, rssi, distance, durationSeconds(NSNumber)
///
/// "peer_lost"   — peer not seen for ≥5 s; contact session ended
///   keys: name, mbti, durationSeconds(NSNumber), avgRssi(NSNumber),
///         startTimeMs(NSNumber<int64>), endTimeMs(NSNumber<int64>)
typedef void (^SWContactEventCallback)(NSDictionary<NSString*, id>* event);

/// Called on the main queue when the BLE radio state changes.
/// Possible values: "ready" "poweredOff" "unauthorized" "unsupported" "resetting" "unknown"
typedef void (^SWBleStateCallback)(NSString* state);

@interface SWBleManager : NSObject

@property (nonatomic, copy, nullable) SWContactEventCallback onContactEvent;
@property (nonatomic, copy, nullable) SWBleStateCallback     onStateChanged;

/// Set the local user's profile. Call before -startBle.
- (void)setProfileWithName:(NSString*)name mbtiIndex:(uint8_t)mbtiIndex;

/// Start advertising (peripheral) + scanning (central) + contact-tracking timer.
- (void)startBle;

/// Stop everything and flush any active contacts as peer_lost events.
- (void)stopBle;

@end

NS_ASSUME_NONNULL_END
