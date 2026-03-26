import 'dart:async';
import 'package:flutter/services.dart';

/// The 16 MBTI types in index order.
/// Must stay in sync with kMbtiTypes[] in sw_profile.h.
const List<String> kMbtiTypes = [
  'INTJ', 'INTP', 'ENTJ', 'ENTP',
  'INFJ', 'INFP', 'ENFJ', 'ENFP',
  'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
  'ISTP', 'ISFP', 'ESTP', 'ESFP',
];

/// Proximity category derived from RSSI.
/// Must stay in sync with SWDistanceCategory in sw_profile.h.
enum DistanceCategory {
  veryClose, // > -60 dBm
  near,      // -60 to -75 dBm
  medium,    // -75 to -85 dBm
  far,       // < -85 dBm
}

DistanceCategory _parseDistance(String? s) {
  switch (s) {
    case 'very_close': return DistanceCategory.veryClose;
    case 'near':       return DistanceCategory.near;
    case 'medium':     return DistanceCategory.medium;
    default:           return DistanceCategory.far;
  }
}

/// The type of a contact session event.
enum ContactEventType {
  /// First advertisement received from a peer.
  found,
  /// Repeated advertisement from an active peer.
  update,
  /// Peer silent for ≥5 s; session ended.
  lost,
}

/// A structured event from the BLE layer describing a peer contact session.
class ContactEvent {
  final ContactEventType type;
  final String name;
  final String mbti;

  /// Instantaneous RSSI (only valid for [found] and [update]).
  final int rssi;

  /// Estimated distance category (only valid for [found] and [update]).
  final DistanceCategory distance;

  /// Elapsed contact time in seconds (0 for [found]).
  final int durationSeconds;

  /// Average RSSI over the session (only meaningful for [lost]).
  final int avgRssi;

  /// Session start/end as Unix-epoch milliseconds (only meaningful for [lost]).
  final int startTimeMs;
  final int endTimeMs;

  const ContactEvent({
    required this.type,
    required this.name,
    required this.mbti,
    this.rssi = 0,
    this.distance = DistanceCategory.far,
    this.durationSeconds = 0,
    this.avgRssi = 0,
    this.startTimeMs = 0,
    this.endTimeMs = 0,
  });
}

/// Main entry point for the sw_ble plugin.
class SwBle {
  static const _method = MethodChannel('sw_ble/methods');
  static const _events = EventChannel('sw_ble/nearby_peers');

  static Stream<ContactEvent>? _eventStream;

  /// Set the local user's profile. Call before [startBle].
  static Future<void> setProfile({
    required String name,
    required int mbtiIndex,
  }) {
    assert(mbtiIndex >= 0 && mbtiIndex < 16);
    return _method.invokeMethod<void>('setProfile', {
      'name': name,
      'mbtiIndex': mbtiIndex,
    });
  }

  /// Start BLE advertising + scanning + contact-tracking.
  static Future<void> startBle() => _method.invokeMethod<void>('startBle');

  /// Stop BLE and flush any active contacts as [ContactEventType.lost].
  static Future<void> stopBle() => _method.invokeMethod<void>('stopBle');

  /// Broadcast stream of [ContactEvent]s.
  ///
  /// Emits [found], [update], and [lost] events for each peer.
  /// Internal `_state` entries are silently filtered out.
  static Stream<ContactEvent> get contactEvents {
    _eventStream ??= _events
        .receiveBroadcastStream()
        .where((e) {
          final map = e as Map?;
          return map != null && map.containsKey('_type');
        })
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          final typeStr = m['_type'] as String? ?? '';

          ContactEventType type;
          switch (typeStr) {
            case 'peer_found':  type = ContactEventType.found;  break;
            case 'peer_update': type = ContactEventType.update; break;
            case 'peer_lost':   type = ContactEventType.lost;   break;
            default: return null;
          }

          return ContactEvent(
            type:            type,
            name:            m['name']            as String? ?? '',
            mbti:            m['mbti']            as String? ?? '',
            rssi:            (m['rssi']            as num?)?.toInt() ?? 0,
            distance:        _parseDistance(m['distance'] as String?),
            durationSeconds: (m['durationSeconds'] as num?)?.toInt() ?? 0,
            avgRssi:         (m['avgRssi']         as num?)?.toInt() ?? 0,
            startTimeMs:     (m['startTimeMs']     as num?)?.toInt() ?? 0,
            endTimeMs:       (m['endTimeMs']       as num?)?.toInt() ?? 0,
          );
        })
        .where((e) => e != null)
        .cast<ContactEvent>();
    return _eventStream!;
  }
}
