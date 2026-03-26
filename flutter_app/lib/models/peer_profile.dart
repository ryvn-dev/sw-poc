import 'package:sw_ble/sw_ble.dart';

class AppPeerProfile {
  final String name;
  final String mbti;
  final int rssi;
  final DistanceCategory distance;
  final DateTime firstSeen;
  final DateTime lastSeen;

  const AppPeerProfile({
    required this.name,
    required this.mbti,
    required this.rssi,
    required this.distance,
    required this.firstSeen,
    required this.lastSeen,
  });

  AppPeerProfile copyWith({int? rssi, DistanceCategory? distance}) =>
      AppPeerProfile(
        name:      name,
        mbti:      mbti,
        rssi:      rssi ?? this.rssi,
        distance:  distance ?? this.distance,
        firstSeen: firstSeen,
        lastSeen:  DateTime.now(),
      );

  /// Elapsed contact time as "m:ss".
  String get durationLabel {
    final secs = DateTime.now().difference(firstSeen).inSeconds.clamp(0, 99999);
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
