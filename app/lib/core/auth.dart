import 'package:flutter/foundation.dart';

import 'api.dart';

/// Trạng thái đăng nhập. go_router nghe thay đổi qua `refreshListenable`.
class Auth extends ChangeNotifier {
  Map<String, dynamic>? user;

  Future<void> load() async {
    try {
      user = Map<String, dynamic>.from(await api('GET', '/api/me'));
    } catch (_) {
      user = null; // 401 hoặc mất mạng → coi như chưa đăng nhập
    }
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await api('POST', '/api/auth/login', {'email': email, 'password': password});
    await load();
  }

  Future<void> register(String email, String password, String displayName) async {
    await api('POST', '/api/auth/register', {
      'email': email,
      'password': password,
      if (displayName.isNotEmpty) 'display_name': displayName,
    });
    await load();
  }

  Future<void> logout() async {
    await api('POST', '/api/auth/logout');
    user = null;
    notifyListeners();
  }
}

final auth = Auth();
