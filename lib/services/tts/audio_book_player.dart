import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../data/models.dart';
import '../../data/storage/book_storage.dart';
import 'edge_tts_engine.dart';
import 'system_tts_engine.dart';
import 'tts_engine.dart';

enum AudioBookStatus { idle, loading, playing, paused, completed, error }

/// 听书状态（供 UI 与阅读页高亮使用）
class AudioBookState {
  const AudioBookState({
    this.status = AudioBookStatus.idle,
    this.segmentIndex = 0,
    this.segmentCount = 0,
    this.bookId,
    this.chapterIndex = 0,
    this.chapterTitle = '',
    this.engine = TtsEngineType.edge,
    this.rate = 1.0,
    this.message,
  });

  final AudioBookStatus status;
  final int segmentIndex;
  final int segmentCount;
  final String? bookId;
  final int chapterIndex;
  final String chapterTitle;
  final TtsEngineType engine;
  final double rate;
  final String? message;

  bool get isPlaying => status == AudioBookStatus.playing || status == AudioBookStatus.loading;

  AudioBookState copyWith({
    AudioBookStatus? status,
    int? segmentIndex,
    int? segmentCount,
    String? bookId,
    int? chapterIndex,
    String? chapterTitle,
    TtsEngineType? engine,
    double? rate,
    String? message,
  }) =>
      AudioBookState(
        status: status ?? this.status,
        segmentIndex: segmentIndex ?? this.segmentIndex,
        segmentCount: segmentCount ?? this.segmentCount,
        bookId: bookId ?? this.bookId,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        engine: engine ?? this.engine,
        rate: rate ?? this.rate,
        message: message,
      );
}

/// 有声书播放器
/// - Edge 引擎：把章节切成句 → 在线合成 mp3（带本地缓存）→ just_audio 无缝串播 + 预取
/// - 系统引擎：交给设备 TTS 逐段朗读
class AudioBookPlayer {
  AudioBookPlayer({TtsEngineType engine = TtsEngineType.edge}) {
    _state = AudioBookState(engine: engine);
  }

  final AudioPlayer _player = AudioPlayer();
  late ConcatenatingAudioSource _playlist;
  late AudioBookState _state;

  final EdgeTtsEngine _edge = EdgeTtsEngine();
  final SystemTtsEngine _system = SystemTtsEngine();

  final StreamController<AudioBookState> _controller =
      StreamController<AudioBookState>.broadcast();

  List<String> _segments = const [];
  int _offset = 0; // playlist 下标 = 段落下标 - _offset
  TtsConfig _config = const TtsConfig(voice: TtsVoice(shortName: 'zh-CN-XiaoxiaoNeural', displayName: '晓晓', locale: 'zh-CN', gender: 'Female'));
  TtsEngineType _engineType = TtsEngineType.edge;
  String _cacheDir = '';
  Future<void> _chain = Future<void>.value();
  bool _disposed = false;
  void Function()? onChapterCompleted;

  AudioBookState get state => _state;
  Stream<AudioBookState> get stateStream => _controller.stream;
  AudioPlayer get player => _player;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    // 配置音频会话（部分桌面平台不支持，忽略即可）
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (_) {}
    _cacheDir = (await BookStorage.ttsCacheDir()).path;
    _playlist = ConcatenatingAudioSource(children: const []);
    _player.currentIndexStream.listen((index) {
      if (index == null) return;
      final segment = _offset + index;
      _emit(_state.copyWith(
        status: AudioBookStatus.playing,
        segmentIndex: segment,
      ));
      _enqueuePrepare(segment + 1); // 预取下一句
    });
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && _state.status != AudioBookStatus.idle) {
        _emit(_state.copyWith(status: AudioBookStatus.completed));
        onChapterCompleted?.call();
      }
    });
  }

  void _emit(AudioBookState next) {
    _state = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  TtsEngineType get engineType => _engineType;

  set engineType(TtsEngineType value) {
    if (_engineType == value) return;
    _engineType = value;
    _emit(_state.copyWith(engine: value, status: AudioBookStatus.idle));
    stop();
  }

  /// 朗读一章（从 startSegment 句开始）
  Future<void> playChapter({
    required String bookId,
    required int chapterIndex,
    required String chapterTitle,
    required String content,
    int startSegment = 0,
    TtsConfig? config,
  }) async {
    if (_cacheDir.isEmpty) await init();
    if (config != null) _config = config;
    final segments = TtsTextSplitter.split(content);
    if (segments.isEmpty) return;

    _segments = segments;
    _emit(_state.copyWith(
      status: AudioBookStatus.loading,
      bookId: bookId,
      chapterIndex: chapterIndex,
      chapterTitle: chapterTitle,
      segmentIndex: startSegment.clamp(0, segments.length - 1).toInt(),
      segmentCount: segments.length,
      engine: _engineType,
      rate: _config.rate,
    ));

    if (_engineType == TtsEngineType.system) {
      await _system.speakSequence(
        segments,
        startIndex: startSegment,
        voice: _config.voice,
        rate: _config.rate,
        pitch: _config.pitch,
        volume: _config.volume,
        onSegmentStart: (i) => _emit(_state.copyWith(segmentIndex: i, status: AudioBookStatus.playing)),
        onSegmentDone: (i) => _emit(_state.copyWith(segmentIndex: i)),
        onAllDone: () => _emit(_state.copyWith(status: AudioBookStatus.completed)),
      );
      return;
    }

    await stop(silent: true);
    _offset = startSegment.clamp(0, segments.length - 1).toInt();
    _playlist = ConcatenatingAudioSource(children: const []);

    await _prepareSegment(_offset); // 首句必须先就绪
    if (_playlist.sequence.isEmpty) {
      _emit(_state.copyWith(
        status: AudioBookStatus.error,
        message: '首句合成失败，请检查网络或切换为「系统离线语音」',
      ));
      return;
    }
    await _player.setAudioSource(_playlist, preload: true);
    await _player.setSpeed(1.0);
    await _player.play();
    _enqueuePrepare(_offset + 1);
  }

  Future<void> pause() async {
    if (_engineType == TtsEngineType.system) {
      await _system.pause();
    } else {
      await _player.pause();
    }
    _emit(_state.copyWith(status: AudioBookStatus.paused));
  }

  Future<void> resume() async {
    if (_engineType == TtsEngineType.system) {
      await _system.resume();
    } else {
      await _player.play();
    }
    _emit(_state.copyWith(status: AudioBookStatus.playing));
  }

  Future<void> stop({bool silent = false}) async {
    if (_engineType == TtsEngineType.system) {
      await _system.stop();
    } else {
      try {
        await _player.stop();
      } catch (_) {}
    }
    if (!silent) _emit(_state.copyWith(status: AudioBookStatus.idle));
  }

  /// 跳到某一句
  Future<void> seekSegment(int segment) async {
    if (_engineType == TtsEngineType.system || segment >= _segments.length) return;
    final playIndex = segment - _offset;
    if (playIndex >= 0 && playIndex < _playlist.sequence.length) {
      await _player.seek(Duration.zero, index: playIndex);
      _emit(_state.copyWith(segmentIndex: segment, status: AudioBookStatus.playing));
      return;
    }
    // 不在已加载范围内：从该句重新开始
    await stop(silent: true);
    await playChapter(
      bookId: _state.bookId ?? '',
      chapterIndex: _state.chapterIndex,
      chapterTitle: _state.chapterTitle,
      content: _segments.join(''),
      startSegment: segment,
    );
  }

  /// Edge 引擎变速：重新以新语速合成当前句
  Future<void> setRate(double rate) async {
    _config = _config.copyWith(rate: rate);
    _emit(_state.copyWith(rate: rate));
    if (_engineType == TtsEngineType.edge && _state.isPlaying) {
      await playChapter(
        bookId: _state.bookId ?? '',
        chapterIndex: _state.chapterIndex,
        chapterTitle: _state.chapterTitle,
        content: _segments.join(''),
        startSegment: _state.segmentIndex,
      );
    }
  }

  Future<void> setVoice(TtsVoice voice) async {
    _config = _config.copyWith(voice: voice);
    if (_state.isPlaying && _engineType == TtsEngineType.edge) {
      await playChapter(
        bookId: _state.bookId ?? '',
        chapterIndex: _state.chapterIndex,
        chapterTitle: _state.chapterTitle,
        content: _segments.join(''),
        startSegment: _state.segmentIndex,
      );
    }
  }

  Future<List<TtsVoice>> availableVoices() =>
      _engineType == TtsEngineType.edge ? _edge.voices() : _system.voices();

  /// 串行化合成任务，保证播放列表顺序
  void _enqueuePrepare(int segment) {
    if (segment < _offset || segment >= _segments.length) return;
    _chain = _chain.then((_) => _prepareSegment(segment)).catchError((Object _) {});
  }

  Future<void> _prepareSegment(int segment) async {
    if (_disposed || segment < _offset || segment >= _segments.length) return;
    final playIndex = segment - _offset;
    final currentLength = _playlist.sequence.length;
    if (playIndex < currentLength) return; // 已就绪

    final text = _segments[segment];
    final key = _cacheKey(text);
    final file = File(p.join(_cacheDir, '$key.mp3'));

    if (!file.existsSync() || file.lengthSync() < 128) {
      try {
        final bytes = await _edge.synthesize(
          text,
          voice: _config.voice,
          rate: _config.rate,
          pitch: _config.pitch,
          volume: _config.volume,
        );
        await BookStorage.writeTtsAudio(key, bytes);
      } catch (e) {
        if (segment == _offset) {
          _emit(_state.copyWith(status: AudioBookStatus.error, message: '朗读失败：$e'));
        }
        return;
      }
    }

    if (playIndex == _playlist.sequence.length) {
      await _playlist.add(AudioSource.file(file.path));
    }
  }

  String _cacheKey(String text) {
    final seed = '${_config.voice.shortName}|${_config.rate}|${_config.pitch}|$text';
    return sha1.convert(utf8.encode(seed)).toString().substring(0, 24);
  }

  void dispose() {
    _disposed = true;
    _player.dispose();
    _controller.close();
  }
}
