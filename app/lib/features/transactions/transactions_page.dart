import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../../core/theme.dart';

/// Một dòng giao dịch, dùng chung cho Dashboard và Lịch sử
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onTap});
  final Json tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final income = tx['direction'] == 'in';
    final pending = !income && tx['category_confirmed'] != true;
    final id = tx['category_id'];
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Text(store.categoryIcon(id), style: const TextStyle(fontSize: 24)),
      title: Text(tx['note'] ?? tx['raw_content'] ?? store.categoryName(id), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          '${shortTime(tx['occurred_at'])} · ${pending ? 'chưa rõ nhóm' : store.categoryName(id)}'
          '${tx['source'] == 'sepay' || tx['source'] == 'email' ? ' · 🏦 ngân hàng' : ''}',
          style: pending ? const TextStyle(color: attention) : null),
      trailing: Text('${income ? '+' : ''}${vnd(tx['amount'])}', style: income ? const TextStyle(color: good) : null),
      onTap: onTap,
    );
  }
}

/// S4 Lịch sử: lọc tuần/tháng/nhóm, sửa nhóm, ghi chú
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _range = 'month';
  int? _category;
  List<Json> _items = [];
  bool _hasMore = false;
  bool _loading = true;
  static const _page = 50;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = switch (_range) {
      'week' => ymd(now.subtract(Duration(days: now.weekday - 1))),
      'month' => ymd(DateTime(now.year, now.month)),
      _ => null,
    };
    final q = {
      'limit': '$_page',
      'from': ?from,
      if (_category != null) 'category_id': '$_category',
      if (more && _items.isNotEmpty) 'before': _items.last['occurred_at'] as String,
    };
    try {
      final rows = List<Json>.from(await api('GET', '/api/transactions?${Uri(queryParameters: q).query}'));
      setState(() {
        _items = more ? [..._items, ...rows] : rows;
        _hasMore = rows.length == _page;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(Json tx) async {
    final changed = await showModalBottomSheet<bool>(
        context: context, isScrollControlled: true, builder: (_) => _EditSheet(tx: tx));
    if (changed == true) {
      _load();
      store.refresh();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Lịch sử')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'week', label: Text('Tuần')),
                  ButtonSegment(value: 'month', label: Text('Tháng')),
                  ButtonSegment(value: 'all', label: Text('Tất cả')),
                ],
                selected: {_range},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  _range = s.first;
                  _load();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: _category,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Mọi nhóm')),
                    for (final c in store.categories)
                      DropdownMenuItem(value: c['id'] as int, child: Text('${c['icon']} ${c['name_vi']}')),
                  ],
                  onChanged: (v) {
                    _category = v;
                    _load();
                  },
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(12), children: [
              if (!_loading && _items.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Chưa có khoản nào.'))),
              for (final tx in _items) TxTile(tx: tx, onTap: () => _edit(tx)),
              if (_hasMore) TextButton(onPressed: _loading ? null : () => _load(more: true), child: const Text('Xem thêm')),
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            ]),
          ),
        ]),
      );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.tx});
  final Json tx;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late int? _category = widget.tx['category_id'];
  late final _note = TextEditingController(text: widget.tx['note']);
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _save() => _run(() => api('PATCH', '/api/transactions/${widget.tx['id']}', {
        'category_id': _category,
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      }));

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá khoản này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok == true) await _run(() => api('DELETE', '/api/transactions/${widget.tx['id']}'));
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    final income = tx['direction'] == 'in';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('${income ? '+' : ''}${vnd(tx['amount'])}', style: Theme.of(context).textTheme.headlineSmall),
          Text('${shortTime(tx['occurred_at'])}${tx['raw_content'] != null ? ' · ${tx['raw_content']}' : ''}'),
          const SizedBox(height: 12),
          if (!income) ...[
            const Text('Khoản này thuộc nhóm nào?'),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in store.spendCategories)
                ChoiceChip(
                  label: Text('${c['icon']} ${c['name_vi']}'),
                  selected: _category == c['id'],
                  onSelected: (_) => setState(() => _category = c['id']),
                ),
            ]),
          ],
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú')),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Lưu')),
          TextButton(onPressed: _delete, child: const Text('Xoá khoản này')),
        ]),
      ),
    );
  }
}
