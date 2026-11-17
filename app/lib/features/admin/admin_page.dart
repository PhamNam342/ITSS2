import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../community/labels.dart';

const _status = {'visible': 'đang hiển thị', 'hidden': 'đang tự ẩn', 'removed': 'đã gỡ'};

/// S13 Kiểm duyệt: danh sách báo cáo → Khôi phục / Gỡ bỏ (spec 10.3)
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Json>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = List<Json>.from(await api('GET', '/api/admin/reports'));
      setState(() => _items = r);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _act(Json r, String action) async {
    await api('POST', '/api/admin/${r['target_type']}/${r['target_id']}/$action');
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Kiểm duyệt')),
        body: _items == null
            ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(12), children: [
                  if (_items!.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Không có báo cáo nào đang chờ 🌿')),
                  for (final r in _items!)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${r['target_type'] == 'post' ? 'Tình huống' : 'Giải pháp'} · ${r['reports']} báo cáo · '
                            '${_status[r['status']] ?? '-'} · ${timeAgo(r['last_at'])}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Wrap(spacing: 6, children: [
                            for (final reason in r['reasons']) Chip(label: Text(reportLabels[reason] ?? reason)),
                          ]),
                          Text(r['body'] ?? '(đã xoá)'),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton(onPressed: () => _act(r, 'restore'), child: const Text('Khôi phục')),
                            FilledButton.tonal(onPressed: () => _act(r, 'remove'), child: const Text('Gỡ bỏ')),
                          ]),
                        ]),
                      ),
                    ),
                ]),
              ),
      );
}
