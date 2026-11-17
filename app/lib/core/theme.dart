import 'package:flutter/material.dart';

// Bảng màu spec mục 13. Không dùng đỏ: màu "error" của theme là cam nhạt.
const primary = Color(0xFF5B8DEF);
const background = Color(0xFFF7F8FC);
const good = Color(0xFF3CB179);
const attention = Color(0xFFF2A65A);

final appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: primary, surface: background, error: attention),
  scaffoldBackgroundColor: background,
);
