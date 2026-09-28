import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'book_parser.dart';

/// EPUB 解析引擎：解压 → 定位 OPF → 按 spine 顺序抽取正文 → 纯文本切片。
class EpubParser implements BookParser {
  @override
  Future<ParsedBook> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);

    final container = _findFile(archive, 'META-INF/container.xml');
    if (container == null) {
      throw const FormatException('不是合法的 EPUB 文件：缺少 container.xml');
    }
    final opfPath = _readRootFilePath(utf8.decode(container.content));
    final opf = _findFile(archive, opfPath) ??
        _findFile(archive, opfPath.split('/').last);
    if (opf == null) {
      throw const FormatException('不是合法的 EPUB 文件：缺少 OPF 描述文件');
    }
    final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/')) : '';
    final opfXml = utf8.decode(opf.content);

    final title = _meta(opfXml, 'title') ?? '未命名';
    final author = _meta(opfXml, 'creator') ?? '佚名';
    final description = _meta(opfXml, 'description') ?? '';

    final manifest = _manifest(opfXml); // id -> href
    final spine = _spine(opfXml); // id 列表

    final chapters = <ParsedChapter>[];
    var index = 0;
    for (final id in spine) {
      final href = manifest[id];
      if (href == null) continue;
      final realPath = opfDir.isEmpty ? href : '$opfDir/$href';
      final file = _findFile(archive, realPath) ?? _findFile(archive, href);
      if (file == null) continue;
      final raw = utf8.decode(file.content, allowMalformed: true);
      final chapterTitle = _chapterTitle(raw) ?? '第 ${index + 1} 章';
      final content = _htmlToText(raw);
      if (content.trim().isEmpty) continue;
      chapters.add(ParsedChapter(title: chapterTitle, content: content));
      index++;
    }

    if (chapters.isEmpty) {
      throw const FormatException('EPUB 中没有可读取的正文');
    }

    return ParsedBook(
      title: title,
      author: author,
      description: description,
      chapters: chapters,
    );
  }

  ArchiveFile? _findFile(Archive archive, String name) {
    for (final f in archive.files) {
      if (f.name == name) return f;
    }
    for (final f in archive.files) {
      if (f.name.endsWith(name)) return f;
    }
    return null;
  }

  String _readRootFilePath(String containerXml) {
    final doc = XmlDocument.parse(containerXml);
    for (final e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'rootfile' && e.getAttribute('full-path') != null) {
        return e.getAttribute('full-path')!;
      }
    }
    throw const FormatException('container.xml 中没有 rootfile');
  }

  String? _meta(String opfXml, String localName) {
    final doc = XmlDocument.parse(opfXml);
    for (final e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == localName && e.innerText.trim().isNotEmpty) {
        return e.innerText.trim();
      }
    }
    return null;
  }

  Map<String, String> _manifest(String opfXml) {
    final doc = XmlDocument.parse(opfXml);
    final map = <String, String>{};
    for (final e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'item') {
        final id = e.getAttribute('id');
        final href = e.getAttribute('href');
        if (id != null && href != null) {
          map[id] = Uri.decodeComponent(href.split('#').first);
        }
      }
    }
    return map;
  }

  List<String> _spine(String opfXml) {
    final doc = XmlDocument.parse(opfXml);
    final ids = <String>[];
    for (final e in doc.descendants.whereType<XmlElement>()) {
      if (e.name.local == 'itemref') {
        final idref = e.getAttribute('idref');
        if (idref != null) ids.add(idref);
      }
    }
    return ids;
  }

  String? _chapterTitle(String html) {
    try {
      final doc = XmlDocument.parse(html);
      for (final e in doc.descendants.whereType<XmlElement>()) {
        final local = e.name.local;
        if (local == 'h1' || local == 'h2' || local == 'h3' || local == 'title') {
          final t = e.innerText.trim();
          if (t.isNotEmpty) return t.length > 40 ? '${t.substring(0, 40)}…' : t;
        }
      }
    } catch (_) {
      // 非严格 XML，走正则兜底
    }
    final m = RegExp(r'<h[1-4][^>]*>([\s\S]*?)</h[1-4]>', caseSensitive: false).firstMatch(html);
    return m?.group(1)?.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  String _htmlToText(String html) {
    var s = html;
    s = s.replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<(?:br|/p|/div|/h[1-6]|/li|/tr)[^>]*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&ldquo;', '“');
    s = s.replaceAll('&rdquo;', '”');
    s = s.replaceAll('&mdash;', '—');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = s.replaceAll('&quot;', '"');
    s = s.replaceAll('&#39;', "'");
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return '　　${s.trim()}';
  }
}
