import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models.dart';
import 'tts_engine.dart';

/// 系统离线 TTS：调用设备自带引擎，逐段朗读并回调进度（用于跟读高亮）
class SystemTtsEngine implements SpeakingTtsEngine {
  SystemTtsEngine() {
    _tts.setStartHandler(() => _onSegmentStart?.call(_index));
    _tts.setCompletionHandler(_next);
    _tts.setErrorHandler((msg) => _onAllDone?.call());
    _tts.setProgressHandler((text, start, end, word) {
      _onProgress?.call(_index, start, end);
    });
  }

  final FlutterTts _tts = FlutterTts();

  List<String> _segments = const [];
  int _index = 0;
  bool _stopped = false;

  void Function(int index, int wordStart, int wordEnd)? _onProgress;
  void Function(int index)? _onSegmentStart;
  void Function(int index)? _onSegmentDone;
  void Function()? _onAllDone;

  @override
  Future<List<TtsVoice>> voices() async {
    try {
      final raw = await _tts.getVoices;
      final list = (raw ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map((e) => TtsVoice(
                shortName: (e['name'] ?? '').toString(),
                displayName: (e['name'] ?? '').toString(),
                locale: (e['locale'] ?? '').toString(),
                gender: '',
              ))
          .where((v) => v.shortName.isNotEmpty)
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return const [
      TtsVoice(shortName: 'default', displayName: '系统默认语音', locale: 'zh-CN', gender: ''),
    ];
  }

  @override
  Future<void> speakSequence(
    List<String> segments, {
    required int startIndex,
    required TtsVoice voice,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
    void Function(int index, int wordStart, int wordEnd)? onProgress,
    void Function(int index)? onSegmentStart,
    void Function(int index)? onSegmentDone,
    void Function()? onAllDone,
  }) async {
    _segments = segments;
    _index = startIndex;
    _stopped = false;
    _onProgress = onProgress;
    _onSegmentStart = onSegmentStart;
    _onSegmentDone = onSegmentDone;
    _onAllDone = onAllDone;

    await _tts.setLanguage(voice.locale.isEmpty ? 'zh-CN' : voice.locale);
    if (voice.shortName != 'default') {
      await _tts.setVoice({'name': voice.shortName, 'locale': voice.locale});
    }
    await _tts.setSpeechRate(rate.clamp(0.1, 1.0).toDouble());
    await _tts.setPitch(pitch);
    await _tts.setVolume(volume);
    await _speakCurrent();
  }

  Future<void> _speakCurrent() async {
    if (_stopped || _index >= _segments.length) {
      _onAllDone?.call();
      return;
    }
    await _tts.speak(_segments[_index]);
  }

  void _next() {
    _onSegmentDone?.call(_index);
    if (_stopped) return;
    if (_index + 1 >= _segments.length) {
      _onAllDone?.call();
      return;
    }
    _index++;
    _speakCurrent();
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    await _tts.stop();
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> resume() async {
    // flutter_tts 无通用 resume，重新朗读当前段
    await _speakCurrent();
  }
}
