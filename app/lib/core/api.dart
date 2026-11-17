import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Production: rỗng = cùng origin với API. Dev với `flutter run`:
/// --dart-define=API_BASE_URL=http://localhost:8080
const apiBase = String.fromEnvironment('API_BASE_URL');

final _client = BrowserClient()..withCredentials = true; // gửi cookie phiên kể cả khi khác origin (dev)

class ApiError implements Exception {
  ApiError(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Gọi API, trả JSON đã decode. Lỗi HTTP → ApiError mang câu thông báo tiếng Việt từ server.
Future<dynamic> api(String method, String path, [Object? body]) async {
  final uri = apiBase.isEmpty ? Uri.base.resolve(path) : Uri.parse('$apiBase$path');
  final req = http.Request(method, uri);
  if (body != null) {
    req.headers['content-type'] = 'application/json';
    req.body = jsonEncode(body);
  }
  final res = await http.Response.fromStream(await _client.send(req));
  final data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
  if (res.statusCode >= 400) {
    final map = data is Map ? data : const {};
    throw ApiError(
      res.statusCode,
      '${map['error'] ?? 'error'}',
      res.statusCode == 400 || map['message'] == null
          ? 'Có gì đó chưa ổn, bạn thử lại nhé.'
          : '${map['message']}',
    );
  }
  return data;
}
