import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'api.dart';

typedef Json = Map<String, dynamic>;

/// Dữ liệu Dashboard + kết nối realtime (SSE, spec 11.2).
class Store extends ChangeNotifier {
  List<Json> categories = [];
  Json? summary;
  List<Json> recent = [];
  web.EventSource? _es;
  final _created = StreamController<Json>.broadcast();
  final _suggested = StreamController<Json>.broadcast();

  /// Giao dịch mới vừa được ghi (từ SSE) – dùng để hiện snackbar
  Stream<Json> get created => _created.stream;

  /// Server gợi ý mở Đánh giá nhanh (khoản chi lớn / bất thường / vừa vượt ngân sách)
  Stream<Json> get quickCheckSuggested => _suggested.stream;

  Json? category(Object? id) {
    for (final c in categories) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  String categoryName(Object? id) => category(id)?['name_vi'] ?? 'Khác';
  String categoryIcon(Object? id) => category(id)?['icon'] ?? '📦';

  /// Các nhóm chi (bỏ "Tiền vào")
  List<Json> get spendCategories => categories.where((c) => c['code'] != 'income').toList();

  /// Các nhóm đặt được ngân sách (bỏ thêm "Chuyển giữa tài khoản của mình": không tính là chi)
  List<Json> get budgetCategories => spendCategories.where((c) => c['code'] != 'self_transfer').toList();

  Future<void> refresh() async {
    try {
      if (categories.isEmpty) categories = List<Json>.from(await api('GET', '/api/categories'));
      final r = await Future.wait([api('GET', '/api/summary'), api('GET', '/api/transactions?limit=5')]);
      summary = Json.from(r[0]);
      recent = List<Json>.from(r[1]);
      notifyListeners();
    } catch (_) {
      // mất mạng: giữ số cũ, lần sau thử lại
    }
  }

  void start() {
    refresh();
    if (_es != null) return;
    _es = web.EventSource('$apiBase/api/events', web.EventSourceInit(withCredentials: true))
      // toJS chỉ nhận hàm trả void (không được trả Future) → thân hàm dạng block
      ..addEventListener('transaction.created', ((web.Event e) {
        _onCreated(e as web.MessageEvent);
      }).toJS)
      ..addEventListener('quick_check.suggested', ((web.Event e) {
        _suggested.add(Json.from(jsonDecode(((e as web.MessageEvent).data as JSString).toDart)));
      }).toJS);
    // Mất kết nối → EventSource tự kết nối lại
  }

  Future<void> _onCreated(web.MessageEvent e) async {
    final tx = Json.from(jsonDecode((e.data as JSString).toDart));
    await refresh();
    _created.add(tx);
  }

  void stop() {
    _es?.close();
    _es = null;
    summary = null;
    recent = [];
    notifyListeners();
  }
}

final store = Store();
