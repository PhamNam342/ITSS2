import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/store.dart';

/// S12 Bảng giả lập (spec 14). Giao dịch đi qua đúng đường của giao dịch ngân hàng thật.
const _presets = [
  ('Trà sữa 35k', 'out', 35000, 'THANH TOAN QR TOCOTOCO'),
  ('Grab 42k', 'out', 42000, 'GRAB*TRIP'),
  ('Shopee 289k', 'out', 289000, 'SHOPEE PAY'),
  ('Sửa laptop 1.200k', 'out', 1200000, 'CHUYEN TIEN SUA MAY TINH'),
  ('Bố mẹ gửi 3.000k', 'in', 3000000, 'BO ME GUI TIEN'),
];

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  String _direction = 'out';
  final _amount = TextEditingController();
  final _content = TextEditingController();

  Future<void> _run(Future<dynamic> Function() action, [String? done]) async {
    final m = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) {
        await store.refresh();
        m.showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _create(String direction, int amount, String content) => _run(() => api(
      'POST', '/api/demo/transactions', {'direction': direction, 'amount': amount, 'content': content}));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Chế độ Demo')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Bấm để giả lập một giao dịch ngân hàng vừa đồng bộ về.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in _presets)
              FilledButton.tonal(onPressed: () => _create(p.$2, p.$3, p.$4), child: Text(p.$1)),
          ]),
          const Divider(height: 32),
          Text('Tuỳ chỉnh', style: Theme.of(context).textTheme.titleMedium),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'out', label: Text('Tiền ra')),
              ButtonSegment(value: 'in', label: Text('Tiền vào')),
            ],
            selected: {_direction},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Số tiền', suffixText: 'đ'),
          ),
          TextField(controller: _content, decoration: const InputDecoration(labelText: 'Nội dung chuyển khoản')),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              final amount = int.tryParse(_amount.text) ?? 0;
              if (amount > 0 && _content.text.trim().isNotEmpty) _create(_direction, amount, _content.text.trim());
            },
            child: const Text('Tạo giao dịch'),
          ),
          const Divider(height: 32),
          OutlinedButton(
            onPressed: () => _run(() => api('POST', '/api/demo/seed'), 'Đã tạo dữ liệu mẫu 2 tuần'),
            child: const Text('Tạo dữ liệu 2 tuần'),
          ),
          TextButton(
            onPressed: () => _run(() => api('DELETE', '/api/demo/transactions'), 'Đã xoá dữ liệu demo'),
            child: const Text('Xoá dữ liệu demo'),
          ),
        ]),
      );
}
