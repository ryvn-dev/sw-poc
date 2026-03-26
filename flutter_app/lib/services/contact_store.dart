import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _kStoreKey = 'sw_contact_history';
const _kMaxRecords = 100;

/// A completed contact session persisted locally.
class ContactRecord {
  final String name;
  final String mbti;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSeconds;
  final int avgRssi;
  /// Highest RSSI (= closest approach) during the session.
  final int closestRssi;

  const ContactRecord({
    required this.name,
    required this.mbti,
    required this.startTime,
    required this.endTime,
    required this.durationSeconds,
    required this.avgRssi,
    required this.closestRssi,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mbti': mbti,
        'startTimeMs': startTime.millisecondsSinceEpoch,
        'endTimeMs': endTime.millisecondsSinceEpoch,
        'durationSeconds': durationSeconds,
        'avgRssi': avgRssi,
        'closestRssi': closestRssi,
      };

  factory ContactRecord.fromJson(Map<String, dynamic> j) => ContactRecord(
        name:            j['name'] as String? ?? '',
        mbti:            j['mbti'] as String? ?? '',
        startTime:       DateTime.fromMillisecondsSinceEpoch(
                             (j['startTimeMs'] as num?)?.toInt() ?? 0),
        endTime:         DateTime.fromMillisecondsSinceEpoch(
                             (j['endTimeMs'] as num?)?.toInt() ?? 0),
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
        avgRssi:         (j['avgRssi'] as num?)?.toInt() ?? 0,
        // closestRssi defaults to avgRssi for records saved before this field existed.
        closestRssi:     (j['closestRssi'] as num?)?.toInt() ??
                         (j['avgRssi'] as num?)?.toInt() ?? 0,
      );
}

/// Simple local persistence for contact records using shared_preferences.
/// Keeps the most recent [_kMaxRecords] entries.
class ContactStore {
  /// Append a record. Trims the list to [_kMaxRecords] if needed.
  static Future<void> save(ContactRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStoreKey);
    final list = raw != null
        ? (jsonDecode(raw) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    list.add(record.toJson());
    if (list.length > _kMaxRecords) {
      list.removeRange(0, list.length - _kMaxRecords);
    }

    await prefs.setString(_kStoreKey, jsonEncode(list));
  }

  /// Load all saved records, newest first.
  static Future<List<ContactRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStoreKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.reversed.map(ContactRecord.fromJson).toList();
  }

  /// Erase all records.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStoreKey);
  }
}
