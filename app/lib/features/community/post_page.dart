import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/store.dart';
import 'community_page.dart';
import 'labels.dart';

/// S9 Chi tiết: tình huống + giải pháp + viết giải pháp
class PostPage extends StatefulWidget {
  const PostPage({super.key, required this.id});
  final String id;

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  Json? _post;
  String? _error;
  String _tag = 'adjust_plan';
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = Json.from(await api('GET', '/api/community/posts/${widget.id}'));
      setState(() => _post = p);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _send() async {
    if (_body.text.trim().length < 10) return setState(() => _error = 'Viết thêm chút nữa nhé (ít nhất 10 ký tự).');
    setState(() => _sending = true);
    try {
      await api('POST', '/api/community/solutions', {'post_id': widget.id, 'tag': _tag, 'body': _body.text.trim()});
      _body.clear();
      _error = null;
      await _load();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit() async {
    final c = TextEditingController(text: _post!['body']);
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Sửa nội dung'),
        content: TextField(controller: c, maxLines: 6, maxLength: 1000),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(d, c.text), child: const Text('Lưu')),
        ],
      ),
    );
    if (text == null) return;
    try {
      await api('PATCH', '/api/community/posts/${widget.id}', {'body': text});
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Xoá bài chia sẻ này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Thôi')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok != true) return;
    await api('DELETE', '/api/community/posts/${widget.id}');
    if (mounted) context.go('/community');
  }

  @override
  Widget build(BuildContext context) {
    final p = _post;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tình huống'),
        actions: [
          if (p != null)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'edit' => _edit(),
                'delete' => _delete(),
                _ => reportContent(context, 'post', widget.id),
              },
              itemBuilder: (_) => p['is_mine'] == true
                  ? const [
                      PopupMenuItem(value: 'edit', child: Text('Sửa nội dung')),
                      PopupMenuItem(value: 'delete', child: Text('Xoá bài')),
                    ]
                  : const [PopupMenuItem(value: 'report', child: Text('Báo cáo bài này'))],
            ),
        ],
      ),
      body: p == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!))
          : ListView(padding: const EdgeInsets.all(12), children: [
              PostCard(post: p, full: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                child: Text('Các bạn đã xoay xở thế này (${(p['solutions'] as List).length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final s in p['solutions']) SolutionCard(solution: Json.from(s)),
              if (p['status'] == 'visible') ...[
              const SizedBox(height: 16),
              Text('Bạn có cách nào giúp được không?', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final e in tagLabels.entries)
                  ChoiceChip(label: Text(e.value), selected: _tag == e.key, onSelected: (_) => setState(() => _tag = e.key)),
              ]),
              TextField(
                controller: _body,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(hintText: 'Chia sẻ cách bạn từng làm…'),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              FilledButton(onPressed: _sending ? null : _send, child: const Text('Gửi giải pháp')),
              ], // bài đang tạm ẩn: chưa nhận giải pháp mới
            ]),
    );
  }
}
