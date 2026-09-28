import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/pagination.dart';
import '../../data/models.dart';
import '../../data/storage/book_storage.dart';
import '../../services/tts/audio_book_player.dart';
import '../../services/tts/tts_engine.dart';
import '../../state/reader_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/tts_controller.dart';
import '../../widgets/vertical_text.dart';
import 'reader_sheets.dart';

/// 阅读页：米黄纸感背景 + 分页阅读 + 竖排模式 + 听书联动高亮
class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  PageController? _pageController;
  bool _menuVisible = false;
  String _signature = '';
  int _lastChapter = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(readerControllerProvider.notifier).open(widget.book);
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _schedulePagination(Size size, ReaderSettings settings, ReaderState state) {
    final sig = '${state.chapterIndex}|${state.content.length}|'
        '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}|'
        '${settings.fontSize}|${settings.lineHeight}|${settings.vertical}';
    if (_signature == sig) return;
    _signature = sig;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final style = TextStyle(
        fontSize: settings.fontSize,
        height: settings.lineHeight,
        color: AppColors.readerTextColors[settings.backgroundIndex % 4],
        letterSpacing: 0.6,
      );
      final pages = settings.vertical
          ? Paginator.paginateVertical(
              state.content,
              fontSize: settings.fontSize,
              lineHeight: settings.lineHeight,
              width: size.width - 48,
              height: size.height - 96,
            )
          : Paginator.paginate(
              state.content,
              style: style,
              width: size.width - 40,
              height: size.height - 72,
            );
      ref.read(readerControllerProvider.notifier).applyPages(pages);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final tts = ref.watch(ttsControllerProvider);

    if (state == null || state.loading) {
      return Scaffold(
        backgroundColor: AppColors.readerBackgrounds[settings.backgroundIndex % 4],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bgIndex = settings.backgroundIndex % 4;
    final foreground = AppColors.readerTextColors[bgIndex];

    // 章节切换后回到第一页
    if (_lastChapter != state.chapterIndex) {
      _lastChapter = state.chapterIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController?.jumpToPage(0);
      });
    }
    _pageController ??= PageController(initialPage: state.pageIndex);

    final totalPages = state.pageCount;
    final pageIndex = state.pageIndex.clamp(0, totalPages - 1).toInt();

    return Scaffold(
      backgroundColor: AppColors.readerBackgrounds[bgIndex],
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                _schedulePagination(size, settings, state);

                final page = state.pages.isEmpty
                    ? state.content
                    : state.pages[pageIndex].text;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final w = size.width;
                    final dx = details.localPosition.dx;
                    if (dx < w * 0.3 || dx > w * 0.7) {
                      // 左右 30% 区域为翻页热区
                      final next = settings.vertical ? (dx < w * 0.3) : (dx > w * 0.7);
                      _turnPage(next ? pageIndex + 1 : pageIndex - 1, totalPages);
                      return;
                    }
                    setState(() => _menuVisible = !_menuVisible);
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: totalPages,
                    reverse: settings.vertical,
                    onPageChanged: (i) =>
                        ref.read(readerControllerProvider.notifier).setPage(i),
                    itemBuilder: (context, index) {
                      final text = state.pages.isEmpty
                          ? (index == 0 ? state.content : '')
                          : state.pages[index].text;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 56, 20, 48),
                        child: settings.vertical
                            ? VerticalTextView(
                                text: text,
                                style: TextStyle(
                                  fontSize: settings.fontSize,
                                  color: foreground,
                                  height: 1.1,
                                ),
                              )
                            : RichText(
                                text: TextSpan(
                                  text: text,
                                  style: TextStyle(
                                    fontSize: settings.fontSize,
                                    height: settings.lineHeight,
                                    color: foreground,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // 顶部栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _menuVisible ? 0 : -90,
            left: 0,
            right: 0,
            child: _TopBar(
              title: state.chapterTitle,
              bookTitle: state.book.title,
              foreground: foreground,
              onBack: () => Navigator.of(context).pop(),
              onAi: () => showAiSheet(context, state.book, state.content),
            ),
          ),

          // 底部栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _menuVisible ? 0 : -160,
            left: 0,
            right: 0,
            child: _BottomBar(
              foreground: foreground,
              pageIndex: pageIndex,
              totalPages: totalPages,
              hasPrevChapter: state.chapterIndex > 0,
              hasNextChapter: state.chapterIndex < state.book.chapterCount - 1,
              listening: tts.isPlaying && tts.bookId == state.book.id,
              onToc: () => showTocSheet(context, ref, state.book, state.chapterIndex),
              onListen: () => showListenSheet(
                context,
                ref,
                state.book,
                chapterIndex: state.chapterIndex,
                content: state.content,
              ),
              onSettings: () => showSettingsSheet(context, ref),
              onBookmark: () async {
                await ref.read(readerControllerProvider.notifier).toggleBookmark();
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('书签已更新')));
                }
              },
              onPageChanged: (v) => _turnPage(v.round(), totalPages),
              onPrevChapter: () =>
                  ref.read(readerControllerProvider.notifier).goToChapter(state.chapterIndex - 1),
              onNextChapter: () =>
                  ref.read(readerControllerProvider.notifier).goToChapter(state.chapterIndex + 1),
            ),
          ),

          // 听书跟读高亮提示
          if (tts.isPlaying && tts.bookId == state.book.id)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).padding.top + 12,
              child: _ListeningBadge(state: tts),
            ),
        ],
      ),
    );
  }

  void _turnPage(int target, int totalPages) {
    if (target < 0) {
      final current = ref.read(readerControllerProvider);
      if (current != null) {
        ref.read(readerControllerProvider.notifier).goToChapter(current.chapterIndex - 1);
      }
      return;
    }
    if (target >= totalPages) {
      final s = ref.read(readerControllerProvider);
      if (s != null) {
        ref.read(readerControllerProvider.notifier).goToChapter(s.chapterIndex + 1);
      }
      return;
    }
    _pageController?.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.bookTitle,
    required this.foreground,
    required this.onBack,
    required this.onAi,
  });

  final String title;
  final String bookTitle;
  final Color foreground;
  final VoidCallback onBack;
  final VoidCallback onAi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 8,
        right: 12,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.92),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8)],
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: Icon(Icons.arrow_back_ios_new_rounded, color: foreground)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: foreground)),
                Text(bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: foreground.withValues(alpha: 0.6))),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onAi,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI 解读'),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.foreground,
    required this.pageIndex,
    required this.totalPages,
    required this.hasPrevChapter,
    required this.hasNextChapter,
    required this.listening,
    required this.onToc,
    required this.onListen,
    required this.onSettings,
    required this.onBookmark,
    required this.onPageChanged,
    required this.onPrevChapter,
    required this.onNextChapter,
  });

  final Color foreground;
  final int pageIndex;
  final int totalPages;
  final bool hasPrevChapter;
  final bool hasNextChapter;
  final bool listening;
  final VoidCallback onToc;
  final VoidCallback onListen;
  final VoidCallback onSettings;
  final VoidCallback onBookmark;
  final ValueChanged<double> onPageChanged;
  final VoidCallback onPrevChapter;
  final VoidCallback onNextChapter;

  @override
  Widget build(BuildContext context) {
    final max = (totalPages - 1).clamp(0, 999999).toDouble();
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: hasPrevChapter ? onPrevChapter : null,
                icon: const Icon(Icons.skip_previous_rounded),
                tooltip: '上一章',
              ),
              Expanded(
                child: Slider(
                  value: pageIndex.toDouble().clamp(0, max).toDouble(),
                  max: max,
                  divisions: max <= 0 ? null : totalPages - 1,
                  onChanged: onPageChanged,
                ),
              ),
              IconButton(
                onPressed: hasNextChapter ? onNextChapter : null,
                icon: const Icon(Icons.skip_next_rounded),
                tooltip: '下一章',
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BarItem(icon: Icons.list_rounded, label: '目录', onTap: onToc),
              _BarItem(
                icon: listening ? Icons.headset_rounded : Icons.headset_off_rounded,
                label: listening ? '听书中' : '听书',
                active: listening,
                onTap: onListen,
              ),
              _BarItem(icon: Icons.text_format_rounded, label: '设置', onTap: onSettings),
              _BarItem(icon: Icons.bookmark_border_rounded, label: '书签', onTap: onBookmark),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${pageIndex + 1}/$totalPages',
            style: TextStyle(fontSize: 11, color: foreground.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.icon, required this.label, required this.onTap, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ListeningBadge extends StatelessWidget {
  const _ListeningBadge({required this.state});

  final AudioBookState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.graphic_eq, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            state.segmentCount == 0
                ? '准备中'
                : '朗读 ${state.segmentIndex + 1}/${state.segmentCount}',
            style: const TextStyle(fontSize: 11, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
