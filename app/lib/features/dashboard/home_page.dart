import 'package:flutter/material.dart';

import '../../core/auth.dart';

/// Sprint 1: chỉ chào + đăng xuất. Dashboard thật ở Sprint 2.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final u = auth.user!;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AnTâm Wallet'),
        actions: [
          IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: auth.logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào, ${u['display_name'] ?? u['email']} 👋', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('Tên ẩn danh của bạn trong cộng đồng: ${u['anon_alias']}'),
          ],
        ),
      ),
    );
  }
}
