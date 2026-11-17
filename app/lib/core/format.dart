String _two(int n) => n.toString().padLeft(2, '0');

/// 35000 → "35.000đ" (luôn không dấu; nơi gọi tự diễn đạt "vượt", "+"…, spec 13 tránh số âm).
String vnd(num v) =>
    '${v.abs().round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';

/// ISO → "17/11 12:30" theo giờ máy người dùng
String shortTime(String iso) {
  final t = DateTime.parse(iso).toLocal();
  return '${_two(t.day)}/${_two(t.month)} ${_two(t.hour)}:${_two(t.minute)}';
}

/// DateTime → "2026-11-17"
String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
