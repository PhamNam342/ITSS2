import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/store.dart';

/// Liên kết ngân hàng (Sprint 5): MB qua SePay webhook, Vietcombank qua email biên lai chuyển tiếp
class BankPage extends StatefulWidget {
  const BankPage({super.key});

  @override
  State<BankPage> createState() => _BankPageState();
}

class _BankPageState extends State<BankPage> {
  List<Json>? _links;
  late final StreamSubscription<Json> _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = store.created.listen((_) => _load()); // giao dịch mới về → cập nhật "Nhận gần nhất"
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = List<Json>.from(await api('GET', '/api/bank-links'));
    if (mounted) setState(() => _links = r);
  }

  void _toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _create(String provider) async {
    try {
      final r = Json.from(await api('POST', '/api/bank-links', {'provider': provider}));
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (c) => provider == 'sepay' ? _SepayDialog(r) : _EmailDialog(r),
      );
    } catch (e) {
      _toast('$e');
    }
  }

  Future<void> _remove(Json l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Huỷ liên kết?'),
        content: const Text('Giao dịch đã có vẫn giữ nguyên. Sau khi huỷ, app không nhận giao dịch mới từ liên kết này.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Huỷ liên kết')),
        ],
      ),
    );
    if (ok != true) return;
    await api('DELETE', '/api/bank-links/${l['id']}');
    await _load();
  }

  Widget _linkTile(Json l) {
    final email = l['provider'] == 'vcb_email';
    final name = [l['bank_short_name'] ?? (email ? 'Vietcombank' : 'SePay'), l['account_number_masked']]
        .whereType<String>()
        .join(' ');
    final last = l['last_webhook_at'];
    final confirm = l['gmail_confirm'];
    return ListTile(
      leading: Icon(email ? Icons.mail_outline : Icons.account_balance),
      title: Text(name),
      subtitle: Text([
        if (confirm != null && last == null) 'Mã xác nhận Gmail: $confirm',
        last == null ? 'Chờ giao dịch đầu tiên' : 'Nhận gần nhất ${timeAgo(last)}',
      ].join('\n')),
      isThreeLine: confirm != null && last == null,
      trailing: IconButton(tooltip: 'Huỷ liên kết', icon: const Icon(Icons.link_off), onPressed: () => _remove(l)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final links = _links;
    return Scaffold(
      appBar: AppBar(title: const Text('Liên kết ngân hàng')),
      body: links == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Giao dịch từ ngân hàng sẽ tự vào app và tự phân loại. '
                  'App chỉ đọc giao dịch, không bao giờ hỏi mật khẩu ngân hàng.'),
              const SizedBox(height: 12),
              for (final l in links) _linkTile(l),
              if (links.isNotEmpty) const Divider(),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.account_balance),
                  title: const Text('MB Bank qua SePay'),
                  subtitle: const Text('Cần tài khoản SePay (gói Free được 50 giao dịch tiền vào mỗi tháng)'),
                  trailing: const Icon(Icons.add),
                  onTap: () => _create('sepay'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('Vietcombank qua email biên lai'),
                  subtitle: const Text('Gmail tự chuyển tiếp email biên lai của VCB Digibank về app'),
                  trailing: const Icon(Icons.add),
                  onTap: () => _create('vcb_email'),
                ),
              ),
            ]),
    );
  }
}

/// Ô chữ có nút sao chép
class _Copyable extends StatelessWidget {
  const _Copyable(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: SelectableText(value, style: const TextStyle(fontFamily: 'monospace')),
        trailing: IconButton(
          tooltip: 'Sao chép',
          icon: const Icon(Icons.copy),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã sao chép $label')));
            }
          },
        ),
      );
}

Widget _steps(List<String> steps) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${i + 1}. ${steps[i]}')),
      ],
    );

const _onceNote = Text('Key chỉ hiện một lần. Lỡ mất thì huỷ liên kết này và tạo cái mới.',
    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic));

class _SepayDialog extends StatelessWidget {
  const _SepayDialog(this.r);
  final Json r;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Liên kết MB qua SePay'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _steps([
              'Đăng ký tài khoản tại sepay.vn, vào "Ngân hàng" → thêm MB Bank cá nhân (nhập số TK, CCCD, xác nhận OTP).',
              'Vào "Webhooks" → "Thêm webhook". Sự kiện: "Cả hai" (tiền vào và tiền ra), chọn tài khoản MB vừa thêm.',
              'Dán URL bên dưới vào ô URL. Phần xác thực chọn "API Key" và dán key bên dưới.',
              'Lưu lại. Từ giao dịch tiếp theo, app tự nhận.',
            ]),
            _Copyable('URL webhook', '${r['webhook_url']}'),
            _Copyable('API Key', '${r['api_key']}'),
            _onceNote,
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Mình đã lưu xong'))],
      );
}

class _EmailDialog extends StatelessWidget {
  const _EmailDialog(this.r);
  final Json r;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Liên kết Vietcombank qua email'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _steps([
              'Trong VCB Digibank: Cài đặt → Quản lý email → Đăng ký nhận kết quả giao dịch qua email (dùng Gmail).',
              'Trong Gmail trên máy tính: Cài đặt → Chuyển tiếp và POP/IMAP → Thêm địa chỉ chuyển tiếp → dán địa chỉ bên dưới.',
              'Gmail gửi mã xác nhận tới địa chỉ đó. Mở lại trang Liên kết ngân hàng, mã hiện dưới liên kết này. Nhập mã vào Gmail.',
              'Tạo bộ lọc Gmail với nội dung tìm kiếm bên dưới → "Chuyển tiếp tới" địa chỉ vừa thêm. '
                  'Bộ lọc chỉ lấy email biên lai, các email khác của Vietcombank (như OTP) không bị chuyển đi.',
            ]),
            _Copyable('Địa chỉ chuyển tiếp', '${r['address']}'),
            const _Copyable('Bộ lọc Gmail', 'from:(VCBDigibank@info.vietcombank.com.vn) subject:("Biên lai")'),
            const Text('Địa chỉ chỉ hiện một lần. Lỡ mất thì huỷ liên kết này và tạo cái mới.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Mình đã lưu xong'))],
      );
}
