import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_reader/services/tts/tts_engine.dart';

void main() {
  group('TtsTextSplitter', () {
    test('空文本返回空列表', () {
      expect(TtsTextSplitter.split(''), isEmpty);
      expect(TtsTextSplitter.split('   \n\t  '), isEmpty);
    });

    test('按句末标点切句', () {
      expect(TtsTextSplitter.split('你好。世界！'), ['你好。', '世界！']);
    });

    test('中英文混排标点均可切分', () {
      final r = TtsTextSplitter.split('Hello world! 你好吗？好的。');
      expect(r.length, 3);
      expect(r.first, 'Hello world!');
    });

    test('短句合并，不超过 maxChars 过多', () {
      final text = List.generate(10, (i) => '第${i + 1}句补充内容。').join();
      final chunks = TtsTextSplitter.split(text, maxChars: 20);
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(60));
      }
      // 合并后不丢字
      expect(chunks.join('').replaceAll(' ', '').length,
          text.replaceAll(' ', '').length);
    });

    test('无标点超长文本硬切且不丢字', () {
      final raw = 'a' * 500;
      final chunks = TtsTextSplitter.split(raw, maxChars: 100);
      expect(chunks.length, greaterThanOrEqualTo(5));
      expect(chunks.join('').length, 500);
    });

    test('管道符等噪声被清理', () {
      final r = TtsTextSplitter.split('正文一｜正文二|正文三。');
      expect(r.single, '正文一 正文二 正文三。');
    });
  });
}
