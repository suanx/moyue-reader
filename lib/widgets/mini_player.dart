import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../services/tts/audio_book_player.dart';
import '../state/tts_controller.dart';

/// 悬浮听书条：任何页面都能看到当前朗读进度
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tts = ref.watch(ttsControllerProvider);
    if (tts.status == AudioBookStatus.idle) return const SizedBox.shrink();

    final playing = tts.status == AudioBookStatus.playing || tts.status == AudioBookStatus.loading;
    final percent = tts.segmentCount == 0
        ? 0.0
        : (tts.segmentIndex + 1) / tts.segmentCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(color: Color(0x335B8DEF), blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                tts.engine == TtsEngineType.edge ? Icons.cloud_outlined : Icons.offline_bolt,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tts.chapterTitle.isEmpty ? '正在朗读' : tts.chapterTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent.clamp(0.0, 1.0).toDouble(),
                      minHeight: 3,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => playing
                  ? ref.read(ttsControllerProvider.notifier).pause()
                  : ref.read(ttsControllerProvider.notifier).resume(),
              icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(ttsControllerProvider.notifier).stop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
