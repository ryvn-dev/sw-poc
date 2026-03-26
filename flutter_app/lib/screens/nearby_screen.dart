import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sw_ble/sw_ble.dart';
import '../models/peer_profile.dart';
import '../services/contact_store.dart';
import 'history_screen.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final Map<String, AppPeerProfile> _peers = {};
  StreamSubscription<ContactEvent>? _bleSub;
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _bleSub = SwBle.contactEvents.listen(_onEvent, onError: _onError);
    // Tick every second so durationLabel stays current.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _peers.isNotEmpty) setState(() {});
    });
  }

  void _onEvent(ContactEvent event) {
    switch (event.type) {
      case ContactEventType.found:
        setState(() {
          _peers[event.name] = AppPeerProfile(
            name:      event.name,
            mbti:      event.mbti,
            rssi:      event.rssi,
            distance:  event.distance,
            firstSeen: DateTime.now(),
            lastSeen:  DateTime.now(),
          );
        });

      case ContactEventType.update:
        setState(() {
          final existing = _peers[event.name];
          if (existing != null) {
            _peers[event.name] =
                existing.copyWith(rssi: event.rssi, distance: event.distance);
          }
        });

      case ContactEventType.lost:
        final removed = _peers.remove(event.name);
        if (removed != null) {
          // Persist the completed session.
          ContactStore.save(ContactRecord(
            name:            event.name,
            mbti:            event.mbti,
            startTime:       DateTime.fromMillisecondsSinceEpoch(event.startTimeMs),
            endTime:         DateTime.fromMillisecondsSinceEpoch(event.endTimeMs),
            durationSeconds: event.durationSeconds,
            avgRssi:         event.avgRssi,
            closestRssi:     event.closestRssi,
          ));
          setState(() {});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                '${event.name} left (${_fmtDuration(event.durationSeconds)})',
              ),
              duration: const Duration(seconds: 3),
            ));
          }
        }
    }
  }

  void _onError(Object err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('BLE 錯誤: $err')),
    );
  }

  Future<void> _stop() async {
    _uiTimer?.cancel();
    // stopBle 會呼叫 _flushActiveContactsAsLost，對所有進行中的接觸發出 peer_lost 事件，
    // 讓 _onEvent 把紀錄存入 ContactStore。
    // 必須先 stopBle，再取消訂閱，否則事件會被丟棄，導致主動離開的人沒有歷史紀錄。
    await SwBle.stopBle();
    await Future.delayed(Duration.zero); // 讓 peer_lost 事件跑完一個 microtask cycle
    await _bleSub?.cancel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _bleSub?.cancel();
    _uiTimer?.cancel();
    SwBle.stopBle();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peers = _peers.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby People'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '接觸紀錄',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined),
            tooltip: 'Stop',
            onPressed: _stop,
          ),
        ],
      ),
      body: peers.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning for nearby people…'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: peers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final peer = peers[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _mbtiColor(peer.mbti),
                    child: Text(
                      peer.mbti.isNotEmpty ? peer.mbti[0] : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(peer.name),
                  subtitle: Row(
                    children: [
                      Text(peer.mbti),
                      const SizedBox(width: 8),
                      _DistanceBadge(distance: peer.distance),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        peer.durationLabel,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${peer.rssi} dBm',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _mbtiColor(String mbti) {
    if (mbti.isEmpty) return Colors.grey;
    return mbti[0] == 'E' ? Colors.deepPurple : Colors.teal;
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _DistanceBadge extends StatelessWidget {
  final DistanceCategory distance;
  const _DistanceBadge({required this.distance});

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (distance) {
      DistanceCategory.veryClose => (Icons.sensors,        'Super Close', Colors.green),
      DistanceCategory.near      => (Icons.wifi,           'Near',        Colors.lightGreen),
      DistanceCategory.medium    => (Icons.wifi_2_bar,     'Medium',      Colors.orange),
      DistanceCategory.far       => (Icons.wifi_1_bar,     'Far',         Colors.red),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(label,
            style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
