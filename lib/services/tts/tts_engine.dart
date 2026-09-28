import 'dart:typed_data';

import 'package:moyue_reader/data/models.dart';

enum TtsEngineType {
  /// 微软 Edge 在线神经语音（自然度最高，需要网络）
  edge('Edge 在线语音', '微软神经网络 TTS，音色丰富'),
  /// 系统内置 TTS（离线可用）
  system('系统离线语音', '调用设备 TTS 引擎，无需网络');

  const TtsEngineType(this.label, this.desc);

  final String label;
  final String desc;
}

/// 朗读参数
class TtsConfig {
  const TtsConfig({
    required this.voice,
    this.rate = 1.0,
    this.pitch = 1.0,
    this.volume = 1.0,
  });

  final TtsVoice voice;
  final double rate; // 0.5 ~ 2.0
  final double pitch; // 0.5 ~ 2.0
  final double volume; // 0 ~ 1

  TtsConfig copyWith({TtsVoice? voice, double? rate, double? pitch, double? volume}) =>
      TtsConfig(
        voice: voice ?? this.voice,
        rate: rate ?? this.rate,
        pitch: pitch ?? this.pitch,
        volume: volume ?? this.volume,
      );
}

/// 在线合成引擎：返回音频字节（Edge-TTS）
abstract class SynthesisTtsEngine {
  Future<List<TtsVoice>> voices();
  Future<Uint8List> synthesize(
    String text, {
    required TtsVoice voice,
    required double rate,
    required double pitch,
    required double volume,
  });
}

/// 直接朗读引擎：由设备 TTS 发声，按段落回调进度
abstract class SpeakingTtsEngine {
  Future<List<TtsVoice>> voices();

  Future<void> speakSequence(
    List<String> segments, {
    required int startIndex,
    required TtsVoice voice,
    required double rate,
    required double pitch,
    required double volume,
    void Function(int index, int wordStart, int wordEnd)? onProgress,
    void Function(int index)? onSegmentStart,
    void Function(int index)? onSegmentDone,
    void Function()? onAllDone,
  });

  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
}

/// 把长文本切成适合 TTS 的短句（Edge-TTS 单句过长会超时/截断）
class TtsTextSplitter {
  TtsTextSplitter._();

  static const String _endMarks = '。！？!?；;…';

  /// 逐字扫描切句（不使用正则后行断言，Dart 各平台行为一致）
  static List<String> toSentences(String clean) {
    final sentences = <String>[];
    final buffer = StringBuffer();
    for (final rune in clean.runes) {
      final ch = String.fromCharCode(rune);
      buffer.write(ch);
      if (_endMarks.contains(ch)) {
        final s = buffer.toString().trim();
        if (s.isNotEmpty) sentences.add(s);
        buffer.clear();
      }
    }
    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) sentences.add(tail);
    return sentences;
  }

  static List<String> split(String text, {int maxChars = 200}) {
    final clean = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[｜|]+'), ' ')
        .trim();
    if (clean.isEmpty) return const [];

    final sentences = toSentences(clean);
    if (sentences.isEmpty) sentences.add(clean);

    final chunks = <String>[];
    final buffer = StringBuffer();
    for (final s in sentences) {
      if (buffer.length + s.length > maxChars && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (s.length > maxChars * 2) {
        // 超长无标点文本，硬切
        var start = 0;
        while (start < s.length) {
          final end = (start + maxChars) > s.length ? s.length : start + maxChars;
          chunks.add(s.substring(start, end));
          start = end;
        }
        continue;
      }
      buffer.write(s);
    }
    if (buffer.isNotEmpty) chunks.add(buffer.toString().trim());
    return chunks.where((e) => e.isNotEmpty).toList();
  }
}
