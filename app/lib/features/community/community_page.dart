import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/store.dart';
import '../../core/theme.dart';
import 'labels.dart';

/// Báo cáo một bài / giải pháp (spec 10.1 mục 4). Dùng chung cho danh sách và chi tiết.
Future<void> reportContent(BuildContext context, String type, String id) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Báo cáo nội dung này?'),
      children: [
        for (final e in reportLabels.entries)
          SimpleDialogOption(onPressed: () => Navigator.pop(c, e.key), child: Text(e.value)),
      ],
    ),
  );
  if (reason == null) return;
  await api('POST', '/api/community/reports', {'target_type': type, 'target_id': id, 'reason': reason});
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cảm ơn bạn, mình sẽ xem lại nội dung này.')));
  }
}

/// S7 Đồng cảnh ngộ: Tình huống / Mẹo hay, lọc theo loại khó khăn & nhu cầu
class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key, this.difficulty, this.amount});
  final String? difficulty;
  final String? amount;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Đồng cảnh ngộ'),
            bottom: const TabBar(tabs: [Tab(text: 'Tình huống'), Tab(text: 'Mẹo hay')]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.go('/community/new${difficulty == null ? '' : '?difficulty_type=$difficulty'}'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Chia sẻ'),
          ),
          body: TabBarView(children: [_Posts(difficulty: difficulty, amount: amount), const _Tips()]),
        ),
      );
}

class _Posts extends StatefulWidget {
  const _Posts({this.difficulty, this.amount});
  final String? difficulty;
  final String? amount;

  @override
  State<_Posts> createState() => _PostsState();
}

class _PostsState extends State<_Posts> {
  late String? _difficulty = widget.difficulty;
  late String? _amount = widget.amount;
  String? _need;
  List<Json>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = {'difficulty_type': ?_difficulty, 'amount_range': ?_amount, 'need': ?_need};
    final rows = List<Json>.from(await api('GET', '/api/community/posts?${Uri(queryParameters: q).query}'));
    if (mounted) setState(() => _posts = rows);
  }

  Widget _filter(String hint, Map<String, String> labels, String? value, void Function(String?) set) => Expanded(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: [
            DropdownMenuItem(value: null, child: Text(hint)),
            for (final e in labels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            set(v);
            _load();
          },
        ),
      );

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _filter('Mọi khó khăn', difficultyLabels, _difficulty, (v) => _difficulty = v),
            const SizedBox(width: 12),
            _filter('Mọi nhu cầu', needLabels, _need, (v) => _need = v),
          ]),
        ),
        if (_amount != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: InputChip(
              label: Text('Khoảng tiền: ${amountLabels[_amount]}'),
              onDeleted: () {
                _amount = null;
                _load();
              },
            ),
          ),
        Expanded(
          child: _posts == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
                    if (_posts!.isEmpty)
                      const Padding(padding: EdgeInsets.all(24), child: Text('Chưa có tình huống nào khớp bộ lọc. Bạn là người đầu tiên chia sẻ nhé!')),
                    for (final p in _posts!) PostCard(post: p, onTap: () => context.go('/community/post/${p['id']}')),
                  ]),
                ),
        ),
      ]);
}

/// Thẻ tình huống (danh sách và đầu trang chi tiết)
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap, this.full = false});
  final Json post;
  final VoidCallback? onTap;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final p = post;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p['status'] == 'hidden') // chỉ tác giả thấy bài của mình ở trạng thái này
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('🌿 Bài của bạn đang tạm ẩn vì có báo cáo, chờ kiểm duyệt xem lại.',
                    style: TextStyle(color: attention)),
              ),
            Text('${p['anon_alias']} · ${timeAgo(p['created_at'])}', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              _chip(difficultyLabels[p['difficulty_type']]),
              if (p['expense_type'] != null) _chip(expenseLabels[p['expense_type']]),
              if (p['amount_range'] != null) _chip(amountLabels[p['amount_range']]),
            ]),
            const SizedBox(height: 8),
            Text(p['body'], maxLines: full ? null : 3, overflow: full ? null : TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('Cần: ${needLabels[p['need']]}${full ? '' : ' · ${p['solution_count']} giải pháp'}',
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String? text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Text(text ?? '', style: const TextStyle(fontSize: 12)),
      );
}

/// Một giải pháp: Hữu ích / Đã thử / Báo cáo (spec 10.1 mục 2–4)
class SolutionCard extends StatefulWidget {
  const SolutionCard({super.key, required this.solution});
  final Json solution;

  @override
  State<SolutionCard> createState() => _SolutionCardState();
}

class _SolutionCardState extends State<SolutionCard> {
  late Json s = widget.solution;

  Future<void> _feedback(bool helpful, [String? result]) async {
    await api('PUT', '/api/community/solutions/${s['id']}/feedback', {'helpful': helpful, 'applied_result': ?result});
    setState(() {
      final wasHelpful = s['my_helpful'] == true;
      s = {
        ...s,
        'my_helpful': helpful,
        'my_result': result ?? s['my_result'],
        'helpful_count': (s['helpful_count'] as int) + (helpful == wasHelpful ? 0 : (helpful ? 1 : -1)),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final helpful = s['my_helpful'] == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${tagLabels[s['tag']]} · ${s['anon_alias']}', style: Theme.of(context).textTheme.labelMedium),
            ),
            if (s['is_mine'] != true)
              IconButton(
                tooltip: 'Báo cáo',
                icon: const Icon(Icons.flag_outlined, size: 18),
                onPressed: () => reportContent(context, 'solution', s['id']),
              ),
          ]),
          Padding(padding: const EdgeInsets.only(right: 10), child: Text(s['body'])),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
            TextButton.icon(
              icon: Icon(helpful ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
              label: Text('Hữu ích (${s['helpful_count']})'),
              onPressed: s['is_mine'] == true ? null : () => _feedback(!helpful),
            ),
            if (s['is_mine'] != true)
              PopupMenuButton<String>(
                tooltip: 'Mình đã thử',
                onSelected: (r) => _feedback(r != 'not_worked', r),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'worked', child: Text('Đã thử – hiệu quả')),
                  PopupMenuItem(value: 'partly', child: Text('Đã thử – hiệu quả một phần')),
                  PopupMenuItem(value: 'not_worked', child: Text('Đã thử – chưa hiệu quả')),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    switch (s['my_result']) {
                      'worked' => '✅ Bạn đã thử: hiệu quả',
                      'partly' => '🌗 Bạn đã thử: một phần',
                      'not_worked' => '🤔 Bạn đã thử: chưa hiệu quả',
                      _ => 'Mình đã thử…',
                    },
                    style: const TextStyle(color: primary),
                  ),
                ),
              ),
            if ((s['worked_count'] as int) > 0)
              Text('${s['worked_count']} bạn thấy hiệu quả', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      ),
    );
  }
}

class _Tips extends StatefulWidget {
  const _Tips();

  @override
  State<_Tips> createState() => _TipsState();
}

class _TipsState extends State<_Tips> {
  List<Json>? _tips;

  @override
  void initState() {
    super.initState();
    api('GET', '/api/community/tips').then((r) {
      if (mounted) setState(() => _tips = List<Json>.from(r));
    });
  }

  @override
  Widget build(BuildContext context) => _tips == null
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 96), children: [
          const Padding(
            padding: EdgeInsets.all(4),
            child: Text('Mẹo được nhiều bạn thấy hữu ích', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          for (final t in _tips!) SolutionCard(solution: t),
        ]);
}
