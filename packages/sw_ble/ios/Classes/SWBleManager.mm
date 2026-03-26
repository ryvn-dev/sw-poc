#import "SWBleManager.h"
#include "sw_profile.h"
#include <string>
#include <vector>

// Seconds without an advertisement before a contact is considered lost.
static const NSTimeInterval kContactTimeoutSeconds = 5.0;

// Keys used in the per-peer tracking dictionary (private, not exported).
static NSString* const kKeyFirstSeen    = @"firstSeen";
static NSString* const kKeyLastSeen     = @"lastSeen";
static NSString* const kKeyMbti         = @"mbti";
static NSString* const kKeyRssiSamples  = @"rssiSamples";

@interface SWBleManager () <CBCentralManagerDelegate, CBPeripheralManagerDelegate>

@property (nonatomic, strong) CBCentralManager*    centralManager;
@property (nonatomic, strong) CBPeripheralManager* peripheralManager;
@property (nonatomic, strong) dispatch_queue_t     bleQueue;

@property (nonatomic, assign) uint8_t   mbtiIndex;
@property (nonatomic, copy)   NSString* userName;

@property (nonatomic, assign) BOOL centralReady;
@property (nonatomic, assign) BOOL peripheralReady;
@property (nonatomic, assign) BOOL shouldBeRunning;

// Contact session tracking — accessed on the main queue only.
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSMutableDictionary*>* activeContacts;
@property (nonatomic, strong) NSTimer* timeoutTimer;

@end

@implementation SWBleManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _mbtiIndex       = 0;
        _userName        = @"";
        _centralReady    = NO;
        _peripheralReady = NO;
        _shouldBeRunning = NO;
        _activeContacts  = [NSMutableDictionary dictionary];
        _bleQueue        = dispatch_queue_create("com.swpoc.ble", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - Public API

- (void)setProfileWithName:(NSString*)name mbtiIndex:(uint8_t)mbtiIndex {
    self.userName  = name ?: @"";
    self.mbtiIndex = mbtiIndex;
}

- (void)startBle {
    self.shouldBeRunning = YES;

    if (!self.centralManager) {
        self.centralManager = [[CBCentralManager alloc]
            initWithDelegate:self
                       queue:self.bleQueue
                     options:@{CBCentralManagerOptionShowPowerAlertKey: @YES}];
    }
    if (!self.peripheralManager) {
        self.peripheralManager = [[CBPeripheralManager alloc]
            initWithDelegate:self
                       queue:self.bleQueue
                     options:nil];
    }

    if (self.centralReady)    [self _startScanning];
    if (self.peripheralReady) [self _startAdvertising];

    // Start the timeout-check timer on the main run loop.
    if (!self.timeoutTimer) {
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(_checkTimeouts)
                                                           userInfo:nil
                                                            repeats:YES];
    }
}

- (void)stopBle {
    self.shouldBeRunning = NO;
    [self _stopScanning];
    [self _stopAdvertising];
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    [self _flushActiveContactsAsLost];
}

#pragma mark - BLE helpers

- (void)_startScanning {
    if (!self.centralReady || !self.shouldBeRunning) return;
    CBUUID* uuid = [CBUUID UUIDWithString:@(kSWServiceUUID)];
    [self.centralManager
        scanForPeripheralsWithServices:@[uuid]
                               options:@{CBCentralManagerScanOptionAllowDuplicatesKey: @YES}];
}

- (void)_stopScanning {
    if (self.centralManager) [self.centralManager stopScan];
}

- (void)_startAdvertising {
    if (!self.peripheralReady || !self.shouldBeRunning) return;
    // Encode profile as "<MBTI>|<name>" in the local name field.
    // CBAdvertisementDataServiceDataKey is NOT supported in startAdvertising: — local name
    // is the only writable custom-string field available on iOS.
    NSString* mbtiStr   = @(sw_mbti_name(self.mbtiIndex));
    NSString* localName = [NSString stringWithFormat:@"%@|%@", mbtiStr, self.userName ?: @""];
    CBUUID* uuid = [CBUUID UUIDWithString:@(kSWServiceUUID)];
    [self.peripheralManager startAdvertising:@{
        CBAdvertisementDataServiceUUIDsKey: @[uuid],
        CBAdvertisementDataLocalNameKey:    localName,
    }];
}

- (void)_stopAdvertising {
    if (self.peripheralManager) [self.peripheralManager stopAdvertising];
}

#pragma mark - Contact session tracking

// Called every 1 s on the main queue. Evicts peers silent for ≥ kContactTimeoutSeconds.
- (void)_checkTimeouts {
    NSDate* now = [NSDate date];
    NSArray* keys = [self.activeContacts allKeys];
    for (NSString* name in keys) {
        NSMutableDictionary* contact = self.activeContacts[name];
        NSDate* lastSeen = contact[kKeyLastSeen];
        if ([now timeIntervalSinceDate:lastSeen] >= kContactTimeoutSeconds) {
            [self _emitPeerLostForName:name contact:contact endTime:now];
            [self.activeContacts removeObjectForKey:name];
        }
    }
}

// Emit peer_lost for all remaining active contacts (called on stopBle).
- (void)_flushActiveContactsAsLost {
    NSDate* now = [NSDate date];
    NSArray* keys = [self.activeContacts allKeys];
    for (NSString* name in keys) {
        [self _emitPeerLostForName:name contact:self.activeContacts[name] endTime:now];
    }
    [self.activeContacts removeAllObjects];
}

- (void)_emitPeerLostForName:(NSString*)name
                     contact:(NSMutableDictionary*)contact
                     endTime:(NSDate*)endTime {
    NSDate* firstSeen = contact[kKeyFirstSeen];
    NSString* mbti    = contact[kKeyMbti];
    NSArray<NSNumber*>* samples = contact[kKeyRssiSamples];

    NSTimeInterval duration = [endTime timeIntervalSinceDate:firstSeen];
    int durationSec = (int)MAX(0, round(duration));

    int avgRssi = 0;
    if (samples.count > 0) {
        int64_t sum = 0;
        for (NSNumber* r in samples) sum += r.intValue;
        avgRssi = (int)(sum / (int64_t)samples.count);
    }

    int64_t startMs = (int64_t)([firstSeen timeIntervalSince1970] * 1000.0);
    int64_t endMs   = (int64_t)([endTime   timeIntervalSince1970] * 1000.0);

    [self _fireContactEvent:@{
        @"_type":           @"peer_lost",
        @"name":            name,
        @"mbti":            mbti ?: @"",
        @"durationSeconds": @(durationSec),
        @"avgRssi":         @(avgRssi),
        @"startTimeMs":     @(startMs),
        @"endTimeMs":       @(endMs),
    }];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager*)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            self.centralReady = YES;
            [self _startScanning];
            break;
        default:
            self.centralReady = NO;
            break;
    }
    [self _fireStateCallback:[self _stateString:central.state]];
}

- (void)centralManager:(CBCentralManager*)central
 didDiscoverPeripheral:(CBPeripheral*)peripheral
     advertisementData:(NSDictionary<NSString*, id>*)advertisementData
                  RSSI:(NSNumber*)RSSI {

    // Profile is encoded as "<MBTI>|<name>" in the local name field.
    NSString* localName = advertisementData[CBAdvertisementDataLocalNameKey];
    if (!localName || localName.length == 0) return;

    NSRange sep = [localName rangeOfString:@"|"];
    if (sep.location == NSNotFound) return;

    NSString* mbtiStr = [localName substringToIndex:sep.location];
    NSString* nameStr = [localName substringFromIndex:sep.location + 1];
    if (nameStr.length == 0) return;

    int rssiInt = RSSI.intValue;

    SWDistanceCategory distCat = sw_rssi_to_distance(rssiInt);
    NSString* distStr = @(sw_distance_name(distCat));

    // Must touch activeContacts on main queue.
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDate* now = [NSDate date];
        NSMutableDictionary* existing = self.activeContacts[nameStr];

        if (!existing) {
            // New contact — peer_found
            NSMutableDictionary* entry = [NSMutableDictionary dictionary];
            entry[kKeyFirstSeen]   = now;
            entry[kKeyLastSeen]    = now;
            entry[kKeyMbti]        = mbtiStr;
            entry[kKeyRssiSamples] = [NSMutableArray arrayWithObject:@(rssiInt)];
            self.activeContacts[nameStr] = entry;

            [self _fireContactEvent:@{
                @"_type":    @"peer_found",
                @"name":     nameStr,
                @"mbti":     mbtiStr,
                @"rssi":     @(rssiInt),
                @"distance": distStr,
            }];
        } else {
            // Existing contact — peer_update
            existing[kKeyLastSeen] = now;
            [existing[kKeyRssiSamples] addObject:@(rssiInt)];

            NSDate* firstSeen = existing[kKeyFirstSeen];
            int durationSec   = (int)MAX(0, round([now timeIntervalSinceDate:firstSeen]));

            [self _fireContactEvent:@{
                @"_type":           @"peer_update",
                @"name":            nameStr,
                @"mbti":            mbtiStr,
                @"rssi":            @(rssiInt),
                @"distance":        distStr,
                @"durationSeconds": @(durationSec),
            }];
        }
    });
}

#pragma mark - CBPeripheralManagerDelegate

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager*)peripheral {
    switch (peripheral.state) {
        case CBManagerStatePoweredOn:
            self.peripheralReady = YES;
            [self _startAdvertising];
            break;
        default:
            self.peripheralReady = NO;
            break;
    }
    [self _fireStateCallback:[self _stateString:peripheral.state]];
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager*)peripheral
                                       error:(nullable NSError*)error {
    if (error) NSLog(@"[SWBle] Advertising error: %@", error.localizedDescription);
}

#pragma mark - Helpers

- (void)_fireContactEvent:(NSDictionary*)event {
    SWContactEventCallback cb = self.onContactEvent;
    if (!cb) return;
    // Already on main queue when called from contact-tracking code;
    // dispatch_async is safe either way.
    dispatch_async(dispatch_get_main_queue(), ^{ cb(event); });
}

- (void)_fireStateCallback:(NSString*)state {
    SWBleStateCallback cb = self.onStateChanged;
    if (!cb) return;
    dispatch_async(dispatch_get_main_queue(), ^{ cb(state); });
}

- (NSString*)_stateString:(CBManagerState)state {
    switch (state) {
        case CBManagerStatePoweredOn:    return @"ready";
        case CBManagerStatePoweredOff:   return @"poweredOff";
        case CBManagerStateUnauthorized: return @"unauthorized";
        case CBManagerStateUnsupported:  return @"unsupported";
        case CBManagerStateResetting:    return @"resetting";
        default:                         return @"unknown";
    }
}

@end
