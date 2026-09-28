import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_reader/core/utils/pagination.dart';

void main() {
  group('Paginator 竖排分页', () {
    test('单页放得下时只有一页', () {
      const text = '朝辞白帝彩云间';
      final pages = Paginator.paginateVertical(
        text,
        fontSize: 18,
        lineHeight: 1.6,
        width: 400,
        height: 600,
      );
      expect(pages.length, 1);
      expect(pages.first.text, text);
      expect(pages.first.start, 0);
      expect(pages.first.end, text.length);
    });

    test('多页分页连续且不丢字不重复', () {
      final text = '朝辞白帝彩云间' * 100; // 700 字
      final pages = Paginator.paginateVertical(
        text,
        fontSize: 18,
        lineHeight: 1.6,
        width: 400,
        height: 600,
      );

      expect(pages.length, greaterThan(1));

      // 首尾衔接
      expect(pages.first.start, 0);
      expect(pages.last.end, text.length);
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i].start, pages[i - 1].end);
      }

      // 拼接还原原文
      expect(pages.map((p) => p.text).join(), text);
    });

    test('TextPage.contains 命中区间', () {
      const page = TextPage(start: 10, end: 20, text: '');
      expect(page.contains(10), isTrue);
      expect(page.contains(19), isTrue);
      expect(page.contains(20), isFalse);
      expect(page.contains(9), isFalse);
    });
  });
}
