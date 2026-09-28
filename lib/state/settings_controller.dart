import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage/app_database.dart';

/// 阅读偏好设置（DataStore 职责）
class ReaderSettings {
  const ReaderSettings({
    this.fontSize = 18,
    this.lineHeight = 1.75,
    this.backgroundIndex = 0,
    this.vertical = false,
    this.autoScrollToTts = true,
  });

  final double fontSize;
  final double lineHeight;
  final int backgroundIndex;
  final bool vertical;
  final bool autoScrollToTts;

  ReaderSettings copyWith({
    double? fontSize,
    double? lineHeight,
    int? backgroundIndex,
    bool? vertical,
    bool? autoScrollToTts,
  }) =>
      ReaderSettings(
        fontSize: fontSize ?? this.fontSize,
        lineHeight: lineHeight ?? this.lineHeight,
        backgroundIndex: backgroundIndex ?? this.backgroundIndex,
        vertical: vertical ?? this.vertical,
        autoScrollToTts: autoScrollToTts ?? this.autoScrollToTts,
      );

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'backgroundIndex': backgroundIndex,
        'vertical': vertical,
        'autoScrollToTts': autoScrollToTts,
      };

  factory ReaderSettings.fromJson(Map<dynamic, dynamic> json) => ReaderSettings(
        fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
        lineHeight: (json['lineHeight'] as num?)?.toDouble() ?? 1.75,
        backgroundIndex: (json['backgroundIndex'] as num?)?.toInt() ?? 0,
        vertical: (json['vertical'] as bool?) ?? false,
        autoScrollToTts: (json['autoScrollToTts'] as bool?) ?? true,
      );
}

class SettingsController extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() {
    final raw = AppDatabase.settings().get('reader_settings');
    if (raw is String) {
      try {
        return ReaderSettings.fromJson(jsonDecode(raw) as Map<dynamic, dynamic>);
      } catch (_) {}
    }
    return const ReaderSettings();
  }

  Future<void> _persist(ReaderSettings value) =>
      AppDatabase.settings().put('reader_settings', jsonEncode(value.toJson()));

  Future<void> update(ReaderSettings value) async {
    state = value;
    await _persist(value);
  }

  Future<void> setFontSize(double v) => update(state.copyWith(fontSize: v.clamp(14, 32).toDouble()));
  Future<void> setLineHeight(double v) => update(state.copyWith(lineHeight: v.clamp(1.3, 2.4).toDouble()));
  Future<void> setBackground(int i) => update(state.copyWith(backgroundIndex: i));
  Future<void> setVertical(bool v) => update(state.copyWith(vertical: v));
  Future<void> setFollowTts(bool v) => update(state.copyWith(autoScrollToTts: v));
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, ReaderSettings>(SettingsController.new);
