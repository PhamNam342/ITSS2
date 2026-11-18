import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/auth.dart';
import 'labels.dart';

/// S8 Chia sẻ tình huống ẩn danh theo mẫu 5 trường (spec 10.1)
class NewPostPage extends StatefulWidget {
  const NewPostPage({super.key, this.difficulty});
  final String? difficulty;

  @override
  State<NewPostPage> createState() => _NewPostPageState();
}

class _NewPostPageState extends State<NewPostPage> {
  late String? _difficulty = widget.difficulty;
  String? _expense;
  String? _amount;
  String? _need;
  final _body = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_difficulty == null || _need == null) return setState(() => _error = 'Chọn loại khó khăn và điều bạn cần nhé.');
    if (_body.text.trim().length < 20) return setState(() => _error = 'Kể thêm một chút nữa nhé (ít nhất 20 ký tự).');
    setState(() => _busy = true);
    try {
      final r = await api('POST', '/api/community/posts', {
        'difficulty_type': _difficulty,
        'expense_type': ?_expense,
        'amount_range': ?_amount,
        'need': _need,
        'body': _body.text.trim(),
      });
      if (mounted) context.go('/community/post/${r['id']}');
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Widget _choices(String title, Map<String, String> labels, String? value, void Function(String?) set) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final e in labels.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: value == e.key,
              onSelected: (on) => setState(() => set(on ? e.key : null)),
            ),
        ]),
      ]);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chia sẻ tình huống')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text('Bạn sẽ hiện là "${auth.user?['anon_alias']}". Đừng ghi tên thật, số điện thoại hay số tài khoản nhé.'),
          _choices('Bạn đang gặp khó khăn gì? *', difficultyLabels, _difficulty, (v) => _difficulty = v),
          _choices('Khoản chi phát sinh', expenseLabels, _expense, (v) => _expense = v),
          _choices('Khoảng số tiền', amountLabels, _amount, (v) => _amount = v),
          _choices('Bạn cần gì nhất? *', needLabels, _need, (v) => _need = v),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            maxLines: 5,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Kể ngắn tình huống của bạn *', alignLabelWithHint: true),
          ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          FilledButton(onPressed: _busy ? null : _submit, child: const Text('Đăng ẩn danh')),
        ]),
      );
}
