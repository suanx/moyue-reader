import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 一页文本在整章中的范围
class TextPage {
  const TextPage({required this.start, required this.end, required this.text});

  final int start;
  final int end;
  final String text;

  bool contains(int offset) => offset >= start && offset < end;
}

class _Line {
  _Line({
    required this.text,
    required this.height,
    required this.start,
    required this.end,
    required this.paragraphEnd,
  });

  final String text;
  final double height;
  final int start;
  final int end;
  final bool paragraphEnd;
}

/// 阅读分页器：把整章文本按屏幕尺寸切成页（横排精确按行排版，竖排按列估算）
class Paginator {
  Paginator._();

  /// 横排分页
  static List<TextPage> paginate(
    String text, {
    required TextStyle style,
    required double width,
    required double height,
    double paragraphSpacing = 8,
  }) {
    if (text.isEmpty) return [const TextPage(start: 0, end: 0, text: '')];
    if (width <= 0 || height <= 0) return [TextPage(start: 0, end: text.length, text: text)];

    final lines = <_Line>[];
    var cursor = 0;
    final paragraphs = text.split('\n');

    for (final para in paragraphs) {
      final paraStart = cursor;
      cursor += para.length + 1; // '\n'
      final body = para.isEmpty ? ' ' : para;
      final painter = TextPainter(
        text: TextSpan(text: body, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: width);

      final metrics = painter.computeLineMetrics();
      for (final m in metrics) {
        final y = m.baseline - m.ascent + 1;
        final pos = painter.getPositionForOffset(Offset(0, y));
        final range = painter.getLineBoundary(pos);
        final start = range.start > body.length ? body.length : range.start;
        final end = range.end > body.length ? body.length : range.end;
        lines.add(_Line(
          text: body.substring(start, end),
          height: m.height,
          start: paraStart + start,
          end: paraStart + end,
          paragraphEnd: false,
        ));
      }
      if (lines.isNotEmpty) {
        lines[lines.length - 1] = _Line(
          text: lines.last.text,
          height: lines.last.height,
          start: lines.last.start,
          end: lines.last.end,
          paragraphEnd: true,
        );
      }
    }

    final pages = <TextPage>[];
    var buffer = StringBuffer();
    var pageStart = 0;
    var pageHeight = 0.0;

    void flush(int endOffset) {
      pages.add(TextPage(start: pageStart, end: endOffset, text: buffer.toString()));
      buffer = StringBuffer();
      pageHeight = 0;
      pageStart = endOffset;
    }

    for (final line in lines) {
      final extra = buffer.isNotEmpty ? 0.0 : 0.0;
      final need = line.height + paragraphSpacing + extra;
      if (pageHeight + need > height && buffer.isNotEmpty) {
        final end = line.start;
        flush(end);
      }
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line.text);
      pageHeight += line.height + (line.paragraphEnd ? paragraphSpacing : 0);
    }
    if (buffer.isNotEmpty) {
      pages.add(TextPage(start: pageStart, end: text.length, text: buffer.toString()));
    }
    return pages.isEmpty ? [TextPage(start: 0, end: text.length, text: text)] : pages;
  }

  /// 竖排分页（从右向左分列，每页 N 列）
  static List<TextPage> paginateVertical(
    String text, {
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
  }) {
    final columnWidth = fontSize * lineHeight;
    final columnsPerPage = math.max(1, (width / columnWidth).floor());
    final charsPerColumn = math.max(1, (height / (fontSize * 1.15)).floor());
    final charsPerPage = columnsPerPage * charsPerColumn;

    final pages = <TextPage>[];
    var start = 0;
    while (start < text.length) {
      final end = math.min(start + charsPerPage, text.length);
      pages.add(TextPage(start: start, end: end, text: text.substring(start, end)));
      start = end;
    }
    return pages.isEmpty ? [TextPage(start: 0, end: text.length, text: text)] : pages;
  }
}
