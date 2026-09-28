import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'pages/main_shell.dart';

/// 墨阅 Reader
class MoyueApp extends StatelessWidget {
  const MoyueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '墨阅 Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const MainShell(),
      builder: (context, child) {
        // 统一控制文字缩放，避免系统字号破坏排版
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(
            media.textScaler.scale(1).clamp(0.9, 1.1).toDouble(),
          )),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
