import 'package:hive_flutter/hive_flutter.dart';

/// 轻量本地库：books / notes / settings 三个 Box。
/// （对应架构图里的 Room + DataStore 职责）
class AppDatabase {
  AppDatabase._();

  static const String booksBox = 'books';
  static const String notesBox = 'notes';
  static const String settingsBox = 'settings';

  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(booksBox),
      Hive.openBox<dynamic>(notesBox),
      Hive.openBox<dynamic>(settingsBox),
    ]);
    _ready = true;
  }

  static Box<dynamic> books() => Hive.box<dynamic>(booksBox);
  static Box<dynamic> notes() => Hive.box<dynamic>(notesBox);
  static Box<dynamic> settings() => Hive.box<dynamic>(settingsBox);
}
