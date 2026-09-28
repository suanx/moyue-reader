import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// 书封：无封面时使用渐变 + 书名排版（与参考图一致的简洁风）
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.title,
    this.author,
    this.gradientIndex = 0,
    this.width = 96,
    this.height = 132,
    this.radius = 12,
    this.imageUrl,
  });

  final String title;
  final String? author;
  final int gradientIndex;
  final double width;
  final double height;
  final double radius;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.coverGradients[gradientIndex.abs() % AppColors.coverGradients.length];
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: imageUrl == null ? colors : [colors.first.withValues(alpha: 0.9), colors.last],
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // 书脊
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 6, color: Colors.white.withValues(alpha: 0.28)),
            ),
            // 装饰圆
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: title.length > 6 ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: width < 80 ? 13 : 15,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  if (author != null && author!.isNotEmpty)
                    Text(
                      author!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: width < 80 ? 10 : 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
