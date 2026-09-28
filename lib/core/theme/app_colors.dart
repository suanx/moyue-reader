import 'package:flutter/material.dart';

/// 墨阅配色：白 + 浅蓝为主，蓝紫渐变做点缀，阅读页米黄纸感。
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF4B7BEC);
  static const Color primaryDeep = Color(0xFF3A5FCC);
  static const Color accent = Color(0xFF7B6CF6);
  static const Color gradientStart = Color(0xFF5B8DEF);
  static const Color gradientEnd = Color(0xFF8A6CF7);

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;
  static const Color cardShadow = Color(0x1A2B3A55);

  static const Color textPrimary = Color(0xFF1E2433);
  static const Color textSecondary = Color(0xFF6B7488);
  static const Color textHint = Color(0xFFA7AEBC);

  static const Color divider = Color(0xFFEDF0F6);
  static const Color success = Color(0xFF3FB98B);
  static const Color warning = Color(0xFFF5A623);

  /// 阅读背景：米黄 / 纯白 / 夜间
  static const List<Color> readerBackgrounds = [
    Color(0xFFF7F1E3), // 米黄（参考图阅读页）
    Color(0xFFFFFFFF), // 纯白
    Color(0xFFE8EDF5), // 淡蓝
    Color(0xFF1B1F27), // 夜间
  ];

  static const List<Color> readerTextColors = [
    Color(0xFF2C2A26),
    Color(0xFF22252B),
    Color(0xFF1E2433),
    Color(0xFFB8BECC),
  ];

  /// 书封渐变（用于无封面书籍的占位）
  static const List<List<Color>> coverGradients = [
    [Color(0xFF6A8CF5), Color(0xFF8A6CF7)],
    [Color(0xFF4FC3A1), Color(0xFF3E9BD8)],
    [Color(0xFFF5A26B), Color(0xFFEF6B8C)],
    [Color(0xFF5B8DEF), Color(0xFF3A5FCC)],
    [Color(0xFF7B6CF6), Color(0xFFB06AB3)],
    [Color(0xFF3FB98B), Color(0xFF2F8F9E)],
  ];
}
