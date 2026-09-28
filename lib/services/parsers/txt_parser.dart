import 'dart:io';

import 'package:moyue_reader/data/storage/book_storage.dart';
import 'book_parser.dart';

/// TXT 解析引擎：自动识别章节标题，无标题时按固定字数切片。
class TxtParser implements BookParser {
  TxtParser({this.chunkSize = 3000});

  final int chunkSize;

  @override
  Future<ParsedBook> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final text = BookStorage.decodeString(bytes);

    final title = _guessTitle(filePath, text);
    final chapters = _splitChapters(text);

    return ParsedBook(
      title: title,
      author: '佚名',
      chapters: chapters,
      description: _guessSummary(text),
    );
  }

  String _guessTitle(String path, String text) {
    final name = path.split(RegExp(r'[\\/]')).last;
    final base = name.replaceAll(RegExp(r'\.(txt|TXT)$'), '');
    final cleaned = base.replaceAll(RegExp(r'[（(【\[].*?[）)】\]]'), '').trim();
    return cleaned.isEmpty ? (text.trim().split('\n').firstOrNull ?? '未命名') : cleaned;
  }

  String _guessSummary(String text) {
    final body = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return body.length <= 60 ? body : body.substring(0, 60);
  }

  List<ParsedChapter> _splitChapters(String text) {
    final lines = text.split('\n');
    final starts = <int>[]; // 每个章节首行在 lines 中的下标
    final titles = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.length > 60) continue;
      final m = chapterPattern.firstMatch(line);
      if (m != null) {
        starts.add(i);
        titles.add(line.length > 40 ? '${line.substring(0, 40)}…' : line);
      }
    }

    if (starts.length >= 3) {
      final chapters = <ParsedChapter>[];
      for (var i = 0; i < starts.length; i++) {
        final from = starts[i];
        final to = i + 1 < starts.length ? starts[i + 1] : lines.length;
        final body = lines.sublist(from, to).join('\n').trim();
        if (body.isEmpty) continue;
        chapters.add(ParsedChapter(title: titles[i], content: body));
      }
      if (chapters.isNotEmpty) return chapters;
    }

    // 退化：按字数切片
    final chapters = <ParsedChapter>[];
    final plain = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    var index = 0;
    var part = 1;
    while (index < plain.length) {
      final end = (index + chunkSize) > plain.length ? plain.length : index + chunkSize;
      chapters.add(
        ParsedChapter(
          title: '第 $part 部分',
          content: plain.substring(index, end),
        ),
      );
      index = end;
      part++;
    }
    if (chapters.isEmpty) {
      chapters.add(const ParsedChapter(title: '全文', content: ''));
    }
    return chapters;
  }
}
