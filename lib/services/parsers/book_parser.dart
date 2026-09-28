/// 解析产物：统一为「标题 + 若干章节纯文本」，屏蔽 TXT / EPUB 差异。
class ParsedChapter {
  ParsedChapter({required this.title, required this.content});

  final String title;
  final String content;

  int get length => content.length;
}

class ParsedBook {
  ParsedBook({
    required this.title,
    required this.author,
    required this.chapters,
    this.description = '',
  });

  final String title;
  final String author;
  final String description;
  final List<ParsedChapter> chapters;

  int get charCount => chapters.fold(0, (sum, c) => sum + c.length);
}

/// 多引擎解析的统一入口
abstract class BookParser {
  Future<ParsedBook> parse(String filePath);
}

/// 章节标题识别：第X章/卷/篇/回、Chapter N、数字编号
final RegExp chapterPattern = RegExp(
  r'^\s{0,8}(?:第\s?[0-9零一二三四五六七八九十百千两]+\s?[章节節卷篇回折幕部]|chapter\s+\d+|CHAPTER\s+\d+|\d{1,4}\s*[、.．]\s*)',
  caseSensitive: false,
);
