import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../data/storage/book_storage.dart';
import '../parsers/book_parser.dart';
import '../parsers/epub_parser.dart';
import '../parsers/txt_parser.dart';

/// 本地书籍导入：选择文件 → 多引擎解析 → 章节切片落盘 → 入库
class BookImporter {
  BookImporter._();

  static final BookImporter instance = BookImporter._();

  static const _uuid = Uuid();

  BookParser parserFor(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.epub') return EpubParser();
    return TxtParser();
  }

  Future<Book> importFile(String path) async {
    final parsed = await parserFor(path).parse(path);
    final id = _uuid.v4();

    var index = 0;
    final titles = <String>[];
    for (final chapter in parsed.chapters) {
      final fileName = BookStorage.encodeChapterFileName(index);
      await BookStorage.writeChapter(id, fileName, chapter.content);
      titles.add(chapter.title);
      index++;
    }

    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    await BookStorage.copySource(id, path, ext.isEmpty ? 'txt' : ext);

    final book = Book(
      id: id,
      title: parsed.title,
      author: parsed.author,
      format: p.extension(path).toLowerCase() == '.epub' ? BookFormat.epub : BookFormat.txt,
      addedAt: DateTime.now(),
      coverIndex: id.hashCode.abs() % 6,
      description: parsed.description,
      charCount: parsed.charCount,
      chapterTitles: titles,
    );

    await BookRepository.instance.save(book);
    return book;
  }
}
