import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../../core/theme.dart';

/// S10 Tổng kết tuần (spec 11.4): chỉ điểm tích cực, streak, huy hiệu
class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  Json? _r;
  String? _error;

  @override
  void initState() {
    super.initState();
    api('GET', '/api/review/weekly').then(
      (r) => setState(() => _r = Json.from(r)),
      onError: (e) => setState(() => _error = '$e'),
    );
  }

  String _day(String ymd) => '${ymd.substring(8, 10)}/${ymd.substring(5, 7)}';

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tổng kết tuần')),
      body: r == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('Tuần ${_day(r['week_start'])} – ${_day(r['week_end'])}', style: text.titleMedium),
              const SizedBox(height: 8),
              for (final h in r['highlights'])
                Card(
                  color: Color.alphaBlend(good.withValues(alpha: 0.12), Colors.white),
                  surfaceTintColor: Colors.transparent,
                  child: Padding(padding: const EdgeInsets.all(14), child: Text(h, style: text.bodyLarge)),
                ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Đã chi tuần qua'),
                subtitle: Text(r['prev_total_out'] > 0 ? 'tuần trước đó: ${vnd(r['prev_total_out'])}' : ''),
                trailing: Text(vnd(r['total_out']), style: text.titleMedium),
              ),
              if (r['streak_weeks'] > 0)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Text('🌱', style: TextStyle(fontSize: 24)),
                  title: Text('${r['streak_weeks']} tuần liên tiếp trong ngân sách'),
                ),
              const SizedBox(height: 8),
              Text('Huy hiệu', style: text.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final b in r['badges'])
                  Chip(
                    avatar: Text(b['earned'] == true ? '🏅' : '🔒'),
                    label: Text(b['label']),
                    backgroundColor: b['earned'] == true ? Color.alphaBlend(good.withValues(alpha: 0.15), Colors.white) : null,
                  ),
              ]),
              if ((r['categories'] as List).isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Theo nhóm', style: text.titleMedium),
                for (final c in r['categories'])
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Text(store.categoryIcon(c['category_id']), style: const TextStyle(fontSize: 22)),
                    title: Text(store.categoryName(c['category_id'])),
                    subtitle: c['prev'] > 0 ? Text('tuần trước đó: ${vnd(c['prev'])}') : null,
                    trailing: Text(vnd(c['spent'])),
                  ),
              ],
            ]),
    );
  }
}
