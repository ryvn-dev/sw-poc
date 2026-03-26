import 'package:flutter/material.dart';
import '../services/contact_store.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ContactRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = ContactStore.loadAll();
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除紀錄'),
        content: const Text('確定刪除所有接觸紀錄？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清除')),
        ],
      ),
    );
    if (confirm == true) {
      await ContactStore.clear();
      setState(() => _future = ContactStore.loadAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('接觸紀錄'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清除',
            onPressed: _clear,
          ),
        ],
      ),
      body: FutureBuilder<List<ContactRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snap.data ?? [];
          if (records.isEmpty) {
            return const Center(child: Text('尚無接觸紀錄'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = records[i];
              final endLabel = _timeLabel(r.endTime);
              final durLabel = _fmtDuration(r.durationSeconds);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      r.mbti.isNotEmpty && r.mbti[0] == 'E'
                          ? Colors.deepPurple
                          : Colors.teal,
                  child: Text(
                    r.mbti.isNotEmpty ? r.mbti[0] : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(r.name),
                subtitle: Text('${r.mbti}  ·  ${r.avgRssi} dBm'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(durLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(endLabel,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
