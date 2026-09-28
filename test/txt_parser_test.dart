import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_reader/services/parsers/txt_parser.dart';

Future<Directory> _tempDir() =>
    Directory.systemTemp.createTemp('moyue_parser_test');

void main() {
  group('TxtParser', () {
    test('识别「第X章」标题并正确分章', () async {
      final dir = await _tempDir();
      final file = File('${dir.path}/book.txt');
      await file.writeAsString(
        '第一章 初见\n这是第一段正文。\n'
        '第二章 试探\n这是第二段正文。\n'
        '第三章 定情\n这是第三段正文。\n',
      );

      final parsed = await TxtParser().parse(file.path);

      expect(parsed.chapters.length, 3);
      expect(parsed.chapters.first.title, contains('第一章'));
      expect(parsed.chapters.first.content, contains('第一段正文'));
      expect(parsed.chapters.last.content, contains('第三段正文'));
      expect(parsed.charCount, greaterThan(0));

      await dir.delete(recursive: true);
    });

    test('无章节标记时按字数切片且不丢字', () async {
      final dir = await _tempDir();
      final file = File('${dir.path}/plain.txt');
      final raw = '这是一段没有任何章节标记的正文。' * 400;
      await file.writeAsString(raw);

      final parsed = await TxtParser().parse(file.path);

      expect(parsed.chapters.length, greaterThan(1));
      final joined = parsed.chapters.map((c) => c.content).join();
      expect(joined.replaceAll(RegExp(r'\s'), '').length,
          raw.replaceAll(RegExp(r'\s'), '').length);

      await dir.delete(recursive: true);
    });

    test('文件名用于推断书名', () async {
      final dir = await _tempDir();
      final file = File('${dir.path}/我的书.txt');
      await file.writeAsString('随便一点正文内容。');

      final parsed = await TxtParser().parse(file.path);
      expect(parsed.title, '我的书');

      await dir.delete(recursive: true);
    });
  });
}
