import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 书籍正文与 TTS 缓存的私有目录管理。
class BookStorage {
  BookStorage._();

  static Future<Directory> _root() async {
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(dir.path, 'moyue'));
    if (!root.existsSync()) root.createSync(recursive: true);
    return root;
  }

  /// 每本书一个目录：moyue/books/<id>/chapters/000.txt
  static Future<Directory> bookDir(String bookId) async {
    final dir = Directory(p.join((await _root()).path, 'books', bookId, 'chapters'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<void> writeChapter(String bookId, String fileName, String content) async {
    final dir = await bookDir(bookId);
    File(p.join(dir.path, fileName)).writeAsStringSync(content, flush: true);
  }

  static Future<String> readChapter(String bookId, String fileName) async {
    final dir = await bookDir(bookId);
    final file = File(p.join(dir.path, fileName));
    if (!file.existsSync()) return '';
    return file.readAsStringSync();
  }

  static Future<void> deleteBook(String bookId) async {
    final dir = Directory(p.join((await _root()).path, 'books', bookId));
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }

  /// Edge-TTS 音频缓存目录
  static Future<Directory> ttsCacheDir() async {
    final dir = Directory(p.join((await _root()).path, 'tts_cache'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<String> writeTtsAudio(String key, List<int> bytes) async {
    final dir = await ttsCacheDir();
    final file = File(p.join(dir.path, '$key.mp3'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> clearTtsCache() async {
    final dir = await ttsCacheDir();
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is File) f.deleteSync();
      }
    }
  }

  /// 把导入的原书拷贝到私有目录（避免源文件被删后书读不了）
  static Future<String> copySource(String bookId, String srcPath, String ext) async {
    final dir = Directory(p.join((await _root()).path, 'books', bookId));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final target = p.join(dir.path, 'source.$ext');
    await File(srcPath).copy(target);
    return target;
  }

  static String encodeChapterFileName(int index) =>
      index.toString().padLeft(4, '0') + '.txt';

  static String decodeString(List<int> bytes) {
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return const Utf8Decoder().convert(bytes.sublist(3));
    }
    // UTF-8 尝试；失败则按 GBK 家族兜底处理（可接入 charset_converter）
    try {
      return const Utf8Decoder().convert(bytes);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }
}
