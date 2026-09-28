import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../data/storage/book_storage.dart';
import '../../services/ai/ai_service.dart';
import '../../services/tts/audio_book_player.dart';
import '../../services/tts/tts_engine.dart';
import '../../state/reader_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/tts_controller.dart';

/// 目录
void showTocSheet(BuildContext context, WidgetRef ref, Book book, int current) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('共 ${book.chapterCount} 章', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: book.chapterCount,
              itemBuilder: (context, i) {
                final selected = i == current;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                  title: Text(
                    book.chapterTitles.length > i ? book.chapterTitles[i] : '第 ${i + 1} 章',
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(readerControllerProvider.notifier).goToChapter(i);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// 阅读设置
void showSettingsSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(settingsControllerProvider);
        final notifier = ref.read(settingsControllerProvider.notifier);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('阅读设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('字号'),
                    Expanded(
                      child: Slider(
                        value: s.fontSize,
                        min: 14,
                        max: 32,
                        divisions: 18,
                        label: s.fontSize.toStringAsFixed(0),
                        onChanged: (v) => notifier.setFontSize(v),
                      ),
                    ),
                    Text('${s.fontSize.toStringAsFixed(0)}'),
                  ],
                ),
                Row(
                  children: [
                    const Text('行距'),
                    Expanded(
                      child: Slider(
                        value: s.lineHeight,
                        min: 1.3,
                        max: 2.4,
                        divisions: 11,
                        label: s.lineHeight.toStringAsFixed(2),
                        onChanged: (v) => notifier.setLineHeight(v),
                      ),
                    ),
                    Text(s.lineHeight.toStringAsFixed(2)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('背景', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(4, (i) {
                    final labels = ['米黄', '纯白', '淡蓝', '夜间'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(labels[i]),
                        selected: s.backgroundIndex == i,
                        onSelected: (_) => notifier.setBackground(i),
                        avatar: CircleAvatar(
                          radius: 8,
                          backgroundColor: AppColors.readerBackgrounds[i],
                          foregroundColor: AppColors.readerTextColors[i],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('竖排阅读'),
                  subtitle: const Text('从右向左分列，适合古籍与诗词'),
                  value: s.vertical,
                  onChanged: (v) => notifier.setVertical(v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('听书时自动翻页'),
                  value: s.autoScrollToTts,
                  onChanged: (v) => notifier.setFollowTts(v),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// 听书面板：引擎切换 / 音色 / 语速 / 段落跳转 / 定时关闭
void showListenSheet(
  BuildContext context,
  WidgetRef ref,
  Book book, {
  int? chapterIndex,
  String? content,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ListenSheet(book: book, chapterIndex: chapterIndex, initialContent: content),
  );
}

class _ListenSheet extends ConsumerStatefulWidget {
  const _ListenSheet({required this.book, this.chapterIndex, this.initialContent});

  final Book book;
  final int? chapterIndex;
  final String? initialContent;

  @override
  ConsumerState<_ListenSheet> createState() => _ListenSheetState();
}

class _ListenSheetState extends ConsumerState<_ListenSheet> {
  String _content = '';
  int _chapterIndex = 0;
  bool _loading = true;
  int? _timerMinutes;
  Timer? _timer;
  bool _autoNext = true;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.chapterIndex ?? 0;
    _load();
  }

  Future<void> _load() async {
    final content = widget.initialContent ??
        await BookStorage.readChapter(
          widget.book.id,
          BookStorage.encodeChapterFileName(_chapterIndex),
        );
    if (!mounted) return;
    setState(() {
      _content = content;
      _loading = false;
    });
    ref.read(ttsControllerProvider.notifier).onChapterCompleted(_nextChapter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    ref.read(ttsControllerProvider.notifier).onChapterCompleted(() {});
    super.dispose();
  }

  Future<void> _nextChapter() async {
    if (!_autoNext) return;
    if (_chapterIndex + 1 >= widget.book.chapterCount) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('全书已朗读完毕')));
      }
      return;
    }
    _chapterIndex++;
    final content = await BookStorage.readChapter(
      widget.book.id,
      BookStorage.encodeChapterFileName(_chapterIndex),
    );
    if (!mounted) return;
    setState(() => _content = content);
    await ref.read(ttsControllerProvider.notifier).playChapter(
          book: widget.book,
          chapterIndex: _chapterIndex,
          content: content,
          config: TtsConfig(
            voice: ref.read(selectedVoiceProvider) ??
                const TtsVoice(
                    shortName: 'zh-CN-XiaoxiaoNeural',
                    displayName: '晓晓',
                    locale: 'zh-CN',
                    gender: 'Female'),
            rate: ref.read(speechRateProvider),
          ),
        );
  }

  void _setTimer(int? minutes) {
    _timer?.cancel();
    setState(() => _timerMinutes = minutes);
    if (minutes == null) return;
    _timer = Timer(Duration(minutes: minutes), () {
      ref.read(ttsControllerProvider.notifier).stop();
      if (mounted) setState(() => _timerMinutes = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsControllerProvider);
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final voice = ref.watch(selectedVoiceProvider);
    final rate = ref.watch(speechRateProvider);
    final playing = tts.status == AudioBookStatus.playing || tts.status == AudioBookStatus.loading;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: _loading
            ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.headphones_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _chapterIndex < widget.book.chapterTitles.length
                              ? widget.book.chapterTitles[_chapterIndex]
                              : '第 ${_chapterIndex + 1} 章',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await ref.read(ttsControllerProvider.notifier).stop();
                          if (mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<TtsEngineType>(
                    segments: TtsEngineType.values
                        .map((e) => ButtonSegment<TtsEngineType>(value: e, label: Text(e.label)))
                        .toList(),
                    selected: {tts.engine},
                    onSelectionChanged: (set) {
                      ref.read(ttsControllerProvider.notifier).setEngine(set.first);
                      ref.invalidate(ttsVoicesProvider);
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tts.engine.desc,
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 12),
                  voicesAsync.when(
                    data: (list) => DropdownButtonFormField<TtsVoice>(
                      initialValue: list.any((v) => v.shortName == voice?.shortName)
                          ? list.firstWhere((v) => v.shortName == voice!.shortName)
                          : (list.isEmpty ? null : list.first),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: '音色',
                        prefixIcon: Icon(Icons.record_voice_over_rounded),
                      ),
                      items: list
                          .map((v) => DropdownMenuItem<TtsVoice>(
                                value: v,
                                child: Text('${v.displayName}（${v.locale}）',
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        ref.read(selectedVoiceProvider.notifier).state = v;
                        ref.read(ttsControllerProvider.notifier).setVoice(v);
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('音色加载失败：$e'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('语速', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: rate,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: '${rate.toStringAsFixed(2)}x',
                          onChanged: (v) {
                            ref.read(speechRateProvider.notifier).state = v;
                          },
                          onChangeEnd: (v) =>
                              ref.read(ttsControllerProvider.notifier).setRate(v),
                        ),
                      ),
                      Text('${rate.toStringAsFixed(2)}x',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('定时', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 10),
                      ...[15, 30, 60].map(
                        (m) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$m 分钟'),
                            selected: _timerMinutes == m,
                            onSelected: (_) => _setTimer(_timerMinutes == m ? null : m),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Text('连播', style: TextStyle(fontSize: 13)),
                          Switch(
                            value: _autoNext,
                            onChanged: (v) => setState(() => _autoNext = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => ref.read(ttsControllerProvider.notifier).stop(),
                        icon: const Icon(Icons.stop_rounded),
                      ),
                      const SizedBox(width: 18),
                      IconButton.filled(
                        onPressed: () async {
                          final notifier = ref.read(ttsControllerProvider.notifier);
                          if (playing) {
                            await notifier.pause();
                          } else if (tts.status == AudioBookStatus.paused) {
                            await notifier.resume();
                          } else {
                            await notifier.playChapter(
                              book: widget.book,
                              chapterIndex: _chapterIndex,
                              content: _content,
                              config: TtsConfig(
                                voice: ref.read(selectedVoiceProvider) ??
                                    const TtsVoice(
                                        shortName: 'zh-CN-XiaoxiaoNeural',
                                        displayName: '晓晓',
                                        locale: 'zh-CN',
                                        gender: 'Female'),
                                rate: ref.read(speechRateProvider),
                              ),
                            );
                          }
                        },
                        iconSize: 34,
                        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      ),
                      const SizedBox(width: 18),
                      IconButton.filledTonal(
                        onPressed: () => ref.read(ttsControllerProvider.notifier).seekSegment(0),
                        icon: const Icon(Icons.replay_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (tts.message != null)
                    Text(tts.message!,
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                  Text(
                    tts.segmentCount == 0 ? '准备朗读…' : '第 ${tts.segmentIndex + 1} / ${tts.segmentCount} 句',
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                ],
              ),
      ),
    );
  }
}

/// AI 解读（在阅读页唤起）
void showAiSheet(BuildContext context, Book book, String content) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _AiSheet(book: book, content: content),
  );
}

class _AiSheet extends StatefulWidget {
  const _AiSheet({required this.book, required this.content});

  final Book book;
  final String content;

  @override
  State<_AiSheet> createState() => _AiSheetState();
}

class _AiSheetState extends State<_AiSheet> {
  String _result = '';
  bool _loading = false;
  AiKind _kind = AiKind.summary;

  Future<void> _run(AiKind kind) async {
    setState(() {
      _loading = true;
      _kind = kind;
      _result = '';
    });
    final text = await AiService.instance.generate(kind, widget.book, widget.content);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('AI 解读本章', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                _AiChip(label: '章节概要', kind: AiKind.summary, current: _kind, onTap: _run),
                _AiChip(label: '思维导图', kind: AiKind.mindmap, current: _kind, onTap: _run),
                _AiChip(label: '人物关系', kind: AiKind.characters, current: _kind, onTap: _run),
                _AiChip(label: '金句摘录', kind: AiKind.quotes, current: _kind, onTap: _run),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Text(
                        _result.isEmpty ? '选择一种解读方式，AI 会基于本章内容生成结果。' : _result,
                        style: const TextStyle(fontSize: 14, height: 1.7),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiChip extends StatelessWidget {
  const _AiChip({required this.label, required this.kind, required this.current, required this.onTap});

  final String label;
  final AiKind kind;
  final AiKind current;
  final ValueChanged<AiKind> onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: current == kind,
      onSelected: (_) => onTap(kind),
    );
  }
}
