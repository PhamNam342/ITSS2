import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/auth.dart';
import '../../core/store.dart';

/// S11 Cài đặt
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _set(BuildContext context, Map<String, Object> patch) async {
    try {
      await api('PATCH', '/api/me', patch);
      await auth.load();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá toàn bộ giao dịch?'),
        content: const Text('Ngân sách và tài khoản vẫn giữ nguyên. Việc này không hoàn tác được.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá hết')),
        ],
      ),
    );
    if (ok != true) return;
    await api('DELETE', '/api/transactions');
    await store.refresh();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xoá.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cài đặt')),
        body: ListenableBuilder(
          listenable: auth,
          builder: (context, _) {
            final u = auth.user;
            if (u == null) return const SizedBox();
            return ListView(children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(u['display_name'] ?? u['email']),
                subtitle: Text('${u['email']}\nTên ẩn danh khi bạn chia sẻ trong cộng đồng: ${u['anon_alias']}'),
                isThreeLine: true,
              ),
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: const Text('Ngân sách & ngày nhận tiền'),
                onTap: () => context.go('/onboarding'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Không tính khoản nạp ví vào tổng chi'),
                subtitle: const Text('Bật nếu bạn tự ghi các khoản tiêu bằng MoMo/ZaloPay, để không bị đếm hai lần'),
                value: u['exclude_topup'] == true,
                onChanged: (v) => _set(context, {'exclude_topup': v}),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.science_outlined),
                title: const Text('Chế độ Demo'),
                subtitle: const Text('Giả lập giao dịch ngân hàng, không cần liên kết thật'),
                value: u['demo_mode'] == true,
                onChanged: (v) => _set(context, {'demo_mode': v}),
              ),
              if (u['role'] == 'admin')
                ListTile(
                  leading: const Icon(Icons.shield_outlined),
                  title: const Text('Kiểm duyệt cộng đồng'),
                  onTap: () => context.go('/admin'),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xoá toàn bộ giao dịch'),
                onTap: () => _deleteAll(context),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Đăng xuất'),
                onTap: auth.logout,
              ),
            ]);
          },
        ),
      );
}
