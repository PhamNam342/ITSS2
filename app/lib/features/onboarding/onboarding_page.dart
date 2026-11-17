import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../../core/theme.dart';

/// S2 Thiết lập: ngày nhận tiền, ngân sách tháng, chia theo nhóm, đánh dấu cần thiết
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _incomeDay = (auth.user?['monthly_income_day'] as int?) ?? 1;
  final _total = TextEditingController();
  final _amounts = <int, TextEditingController>{};
  final _essential = <int, bool>{};
  bool _loading = true;
  String? _error;

  int _n(TextEditingController? c) => int.tryParse(c?.text ?? '') ?? 0;
  int get _allocated => _amounts.values.fold(0, (a, c) => a + _n(c));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (store.categories.isEmpty) await store.refresh();
    final budgets = List<Json>.from(await api('GET', '/api/budgets'));
    for (final c in store.spendCategories) {
      final id = c['id'] as int;
      final b = budgets.where((x) => x['category_id'] == id).firstOrNull;
      _amounts[id] = TextEditingController(text: b == null ? '' : '${b['amount']}');
      _essential[id] = (b?['is_essential'] ?? c['default_essential']) as bool;
    }
    final total = budgets.where((x) => x['category_id'] == null).firstOrNull;
    _total.text = total == null ? '' : '${total['amount']}';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final total = _n(_total) > 0 ? _n(_total) : _allocated; // để trống tổng → lấy tổng các nhóm
    if (total <= 0) return setState(() => _error = 'Nhập ngân sách tháng nhé');
    try {
      await api('PATCH', '/api/me', {'monthly_income_day': _incomeDay});
      await api('PUT', '/api/budgets', {
        'total': total,
        'categories': [
          for (final e in _amounts.entries)
            if (_n(e.value) > 0) {'category_id': e.key, 'amount': _n(e.value), 'is_essential': _essential[e.key]},
        ],
      });
      await auth.load(); // cập nhật ngày nhận tiền → Dashboard tự tải lại
      if (mounted) context.go('/');
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final total = _n(_total);
    return Scaffold(
      appBar: AppBar(title: const Text('Ngân sách tháng')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Đặt theo nhịp của bạn – sửa lúc nào cũng được.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _incomeDay,
                decoration: const InputDecoration(labelText: 'Ngày nhận tiền hằng tháng (bố mẹ gửi / lương)'),
                items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('Ngày $d'))],
                onChanged: (v) => _incomeDay = v ?? 1,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _total,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Tổng ngân sách tháng', suffixText: 'đ'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Text('Chia theo nhóm', style: text.titleMedium),
              Text('Đã chia ${vnd(_allocated)}${total > 0 ? ' / ${vnd(total)}' : ''}',
                  style: TextStyle(color: total > 0 && _allocated > total ? attention : null)),
              const Text('"Cần thiết" = khoản khó cắt (ăn, ở, đi lại). App luôn giữ phần này khi tính tiền an toàn mỗi ngày.',
                  style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              for (final c in store.spendCategories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${c['icon']} ${c['name_vi']}')),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _amounts[c['id']],
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(suffixText: 'đ', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Cần thiết'),
                      showCheckmark: false, // giữ chip cùng độ rộng → các ô số thẳng hàng
                      selected: _essential[c['id']] ?? false,
                      onSelected: (v) => setState(() => _essential[c['id']] = v),
                    ),
                  ]),
                ),
              if (_error != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: attention))),
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: const Text('Lưu ngân sách')),
            ]),
    );
  }
}
