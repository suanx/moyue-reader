import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../services/tts/audio_book_player.dart';
import '../services/tts/tts_engine.dart';

/// 全局听书播放器实例
final audioBookPlayerProvider = Provider<AudioBookPlayer>((ref) {
  final player = AudioBookPlayer();
  player.init();
  ref.onDispose(player.dispose);
  return player;
});

/// 听书状态
class TtsController extends Notifier<AudioBookState> {
  @override
  AudioBookState build() {
    final player = ref.watch(audioBookPlayerProvider);
    final sub = player.stateStream.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return player.state;
  }

  AudioBookPlayer get _player => ref.read(audioBookPlayerProvider);

  Future<void> playChapter({
    required Book book,
    required int chapterIndex,
    required String content,
    int startSegment = 0,
    TtsConfig? config,
  }) =>
      _player.playChapter(
        bookId: book.id,
        chapterIndex: chapterIndex,
        chapterTitle: chapterIndex < book.chapterTitles.length
            ? book.chapterTitles[chapterIndex]
            : '第 ${chapterIndex + 1} 章',
        content: content,
        startSegment: startSegment,
        config: config,
      );

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.resume();
  Future<void> stop() => _player.stop();
  Future<void> seekSegment(int index) => _player.seekSegment(index);
  Future<void> setRate(double rate) => _player.setRate(rate);
  Future<void> setVoice(TtsVoice voice) => _player.setVoice(voice);

  void setEngine(TtsEngineType type) => _player.engineType = type;

  void onChapterCompleted(void Function() cb) => _player.onChapterCompleted = cb;
}

final ttsControllerProvider =
    NotifierProvider<TtsController, AudioBookState>(TtsController.new);

/// 可用音色（依赖引擎类型，引擎切换后自动刷新）
final ttsVoicesProvider = FutureProvider<List<TtsVoice>>((ref) async {
  ref.watch(ttsControllerProvider.select((s) => s.engine));
  return ref.read(audioBookPlayerProvider).availableVoices();
});

/// 默认音色选择
final selectedVoiceProvider = StateProvider<TtsVoice?>(
  (ref) => const TtsVoice(
    shortName: 'zh-CN-XiaoxiaoNeural',
    displayName: '晓晓 · 温柔女声',
    locale: 'zh-CN',
    gender: 'Female',
  ),
);

/// 语速
final speechRateProvider = StateProvider<double>((ref) => 1.0);
