import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import '../transactions/add_sheet.dart';
import '../transactions/transactions_page.dart';

/// S3 Dashboard (spec 12)
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([store, auth]),
        builder: (context, _) {
          final s = store.summary;
          return Scaffold(
            appBar: AppBar(
              title: const Text('AnTâm Wallet'),
              actions: [
                if (auth.user?['demo_mode'] == true)
                  IconButton(
                      tooltip: 'Chế độ Demo',
                      icon: const Icon(Icons.science_outlined),
                      onPressed: () => context.go('/demo')),
                IconButton(
                    tooltip: 'Đồng cảnh ngộ',
                    icon: const Icon(Icons.forum_outlined),
                    onPressed: () => context.go('/community')),
                IconButton(
                    tooltip: 'Lịch sử',
                    icon: const Icon(Icons.receipt_long_outlined),
                    onPressed: () => context.go('/transactions')),
                IconButton(
                    tooltip: 'Cài đặt',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => context.go('/settings')),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              tooltip: 'Ghi khoản chi',
              onPressed: () => showAddSheet(context),
              child: const Icon(Icons.add),
            ),
            body: s == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: store.refresh,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: _content(context, s),
                    ),
                  ),
          );
        },
      );

  List<Widget> _content(BuildContext context, Json s) {
    final text = Theme.of(context).textTheme;
    final num total = s['budget_total'], remaining = s['remaining_month'];
    return [
      if (total == 0)
        Card(
          child: ListTile(
            leading: const Text('🌱', style: TextStyle(fontSize: 28)),
            title: const Text('Đặt ngân sách tháng để app tính giúp bạn nhé'),
            trailing: FilledButton(onPressed: () => context.go('/onboarding'), child: const Text('Bắt đầu')),
          ),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(total == 0 ? 'Đã chi tháng này' : 'Còn lại tháng này', style: text.titleSmall),
            const SizedBox(height: 4),
            if (total == 0)
              Text(vnd(s['spent_month']), style: text.headlineMedium)
            else if (remaining >= 0)
              Text(vnd(remaining), style: text.headlineMedium?.copyWith(color: good))
            else // spec 13: không hiện số âm đỏ
              Text('Vượt ${vnd(remaining)} so với kế hoạch', style: text.titleLarge?.copyWith(color: attention)),
            if (total > 0) Text('Đã chi ${vnd(s['spent_month'])} / ${vnd(total)}'),
          ]),
        ),
      ),
      Row(children: [
        Expanded(child: _stat(context, 'An toàn mỗi ngày', vnd(s['safe_per_day']), 'còn ${s['days_left']} ngày tới kỳ nhận tiền')),
        Expanded(child: _stat(context, 'Tuần này đã chi', vnd(s['spent_week']), 'từ thứ Hai')),
      ]),
      Card(
        child: ListTile(
          leading: const Text('🌱', style: TextStyle(fontSize: 24)),
          title: const Text('Tổng kết tuần trước'),
          subtitle: const Text('Những điều bạn đã làm tốt'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/review'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: OutlinedButton.icon(
          icon: const Text('🌿'),
          label: const Text('Mình vừa có khoản chi bất ngờ'),
          onPressed: () => context.go('/quick-check'),
        ),
      ),
      if (s['pending_count'] > 0)
        Card(
          child: ListTile(
            leading: const Text('🤔', style: TextStyle(fontSize: 24)),
            title: Text('Có ${s['pending_count']} khoản chưa rõ nhóm'),
            subtitle: const Text('Chạm để chọn nhóm, chỉ một chạm thôi'),
            onTap: () => context.go('/transactions'),
          ),
        ),
      if ((s['categories'] as List).isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(4, 16, 4, 8), child: Text('Theo nhóm', style: text.titleMedium)),
        for (final c in s['categories']) _categoryBar(context, c),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 0, 0),
        child: Row(children: [
          Expanded(child: Text('Gần đây', style: text.titleMedium)),
          TextButton(onPressed: () => context.go('/transactions'), child: const Text('Xem tất cả')),
        ]),
      ),
      if (store.recent.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có khoản nào. Bấm + để ghi khoản đầu tiên.')),
      for (final tx in store.recent) TxTile(tx: tx, onTap: () => context.go('/transactions')),
    ];
  }

  Widget _stat(BuildContext context, String label, String value, String sub) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(sub, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );

  Widget _categoryBar(BuildContext context, Json c) {
    final num budget = c['budget'], spent = c['spent'];
    final over = budget > 0 && spent > budget;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${store.categoryIcon(c['category_id'])} ${store.categoryName(c['category_id'])}')),
          Text(budget > 0 ? '${vnd(spent)} / ${vnd(budget)}' : '${vnd(spent)} · chưa đặt ngân sách',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: budget > 0 ? min(1, spent / budget) : 1,
          color: over || budget == 0 ? attention : good,
          backgroundColor: Colors.black12,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ]),
    );
  }
}
