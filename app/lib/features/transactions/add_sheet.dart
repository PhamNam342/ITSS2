import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/store.dart';

/// Nhập nhanh một khoản chi, mục tiêu < 5 giây (spec 11.3)
Future<void> showAddSheet(BuildContext context) =>
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const AddSheet());

const _wallets = {'cash': 'Tiền mặt', 'momo': 'MoMo', 'zalopay': 'ZaloPay', 'other': 'Khác'};

class AddSheet extends StatefulWidget {
  const AddSheet({super.key});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  int? _category;
  String _wallet = 'cash';
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount <= 0) return setState(() => _error = 'Nhập số tiền nhé');
    if (_category == null) return setState(() => _error = 'Chọn một nhóm nhé');
    setState(() => _busy = true);
    try {
      await api('POST', '/api/transactions', {
        'amount': amount,
        'category_id': _category,
        'wallet': _wallet,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context); // Dashboard tự cập nhật qua SSE
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text('Ghi khoản chi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Số tiền', suffixText: 'đ'),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final k in [10, 20, 50, 100])
              ActionChip(label: Text('${k}k'), onPressed: () => _amount.text = '${k * 1000}'),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final c in store.spendCategories)
              ChoiceChip(
                label: Text('${c['icon']} ${c['name_vi']}'),
                selected: _category == c['id'],
                onSelected: (_) => setState(() => _category = c['id']),
              ),
          ]),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [for (final w in _wallets.entries) ButtonSegment(value: w.key, label: Text(w.value))],
            selected: {_wallet},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _wallet = s.first),
          ),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)')),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: error))),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Lưu')),
        ]),
      ),
    );
  }
}
