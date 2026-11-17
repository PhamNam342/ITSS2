import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../../core/theme.dart';

/// S6 Đánh giá nhanh (spec 9.3): 3 con số + 1 kết luận, slider giảm khoản linh hoạt.
class QuickCheckPage extends StatefulWidget {
  const QuickCheckPage({super.key});

  @override
  State<QuickCheckPage> createState() => _QuickCheckPageState();
}

const _messages = {
  'light': ('🌿', 'Bạn vẫn ổn.', good),
  'medium': ('🍃', 'Hơi chật một chút, nhưng xoay được. Thử điều chỉnh vài khoản bên dưới nhé.', attention),
  'support': ('🤝', 'Tháng này sẽ hơi khó. Mình cùng xem có thể lùi khoản nào nhé.', Color(0xFF8E7CC3)),
};

const _basis = {
  'bank': 'theo số dư ngân hàng mới nhất',
  'month': 'ước tính: tiền vào − tiền ra trong tháng',
  'budget': 'ước tính theo ngân sách còn lại',
};

class _QuickCheckPageState extends State<QuickCheckPage> {
  Json? _q;
  List<Json> _budgets = [];
  final _cut = <int, double>{}; // category_id → số tiền giảm
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([api('GET', '/api/quick-check'), api('GET', '/api/budgets')]);
      setState(() {
        _q = Json.from(r[0]);
        _budgets = List<Json>.from(r[1]);
        _cut.clear();
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _save() async {
    final totalCut = _cut.values.fold<double>(0, (a, b) => a + b).round();
    final total = _budgets.where((b) => b['category_id'] == null).firstOrNull;
    try {
      await api('PUT', '/api/budgets', {
        'total': max(0, ((total?['amount'] ?? 0) as num).round() - totalCut),
        'categories': [
          for (final b in _budgets.where((b) => b['category_id'] != null))
            {
              'category_id': b['category_id'],
              'amount': max(0, (b['amount'] as num).round() - (_cut[b['category_id']] ?? 0).round()),
              'is_essential': b['is_essential'],
            },
        ],
      });
      await store.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật ngân sách 🌿')));
      _load();
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Scaffold(
      appBar: AppBar(title: const Text('Đánh giá nhanh')),
      body: q == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: _content(q))),
    );
  }

  List<Widget> _content(Json q) {
    final text = Theme.of(context).textTheme;
    final (emoji, message, color) = _messages[q['level']]!;
    final num available = q['available'];
    final adjustable = List<Json>.from(q['adjustable']);
    final plan = adjustable.fold<num>(0, (a, c) => a + c['remaining'] - (_cut[c['category_id']] ?? 0));
    final fits = plan <= max(0, available);
    return [
      Card(
        color: Color.alphaBlend(color.withValues(alpha: 0.15), Colors.white),
        surfaceTintColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                q['level'] == 'light'
                    ? '$message Mỗi ngày còn khoảng ${vnd(q['per_day'])} để chi linh hoạt.'
                    : message,
                style: text.titleMedium,
              ),
            ),
          ]),
        ),
      ),
      _row('Số tiền hiện có', vnd(q['current']), _basis[q['basis']]!),
      _row('Khoản cần thiết còn lại', vnd(q['essential_left']), 'ăn uống, nhà ở, đi lại… chưa chi hết'),
      _row(
        'Có thể dùng đến kỳ nhận tiền',
        vnd(max(0, available)), // spec 13: không hiện số âm
        available >= 0
            ? 'còn ${q['days_left']} ngày'
            : 'còn ${q['days_left']} ngày · thiếu ${vnd(available)} cho khoản cần thiết',
      ),
      if (adjustable.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Lùi bớt khoản linh hoạt', style: text.titleMedium),
        Text(
          fits
              ? 'Kế hoạch chi linh hoạt còn ${vnd(plan)} – vừa với số bạn có 🌿'
              : 'Kế hoạch chi linh hoạt còn ${vnd(plan)}, nhiều hơn số có thể dùng. Thử kéo bớt nhé.',
          style: TextStyle(color: fits ? good : attention),
        ),
        for (final c in adjustable) _slider(c),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _cut.values.any((v) => v > 0) ? _save : null,
          child: const Text('Lưu điều chỉnh vào ngân sách'),
        ),
      ],
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
    ];
  }

  Widget _row(String label, String value, String sub) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        title: Text(label),
        subtitle: Text(sub),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _slider(Json c) {
    final id = c['category_id'] as int;
    final double remaining = (c['remaining'] as num).toDouble();
    final cut = _cut[id] ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text('${store.categoryIcon(id)} ${store.categoryName(id)}')),
        Text(cut > 0 ? 'giảm ${vnd(cut)}' : 'còn ${vnd(remaining)}'),
      ]),
      Slider(
        value: cut,
        max: remaining,
        divisions: max(1, min(100, (remaining / 10000).ceil())),
        label: vnd(cut),
        onChanged: (v) => setState(() => _cut[id] = v),
      ),
    ]);
  }
}
