import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/library_controller.dart';
import '../state/tts_controller.dart';
import '../widgets/mini_player.dart';
import 'ai/ai_center_page.dart';
import 'discover_page.dart';
import 'reader/reader_sheets.dart';
import 'shelf_page.dart';

/// 主框架：发现 / 书架 / AI 中心 + 悬浮听书条
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  final List<Widget> _pages = const [
    DiscoverPage(),
    ShelfPage(),
    AiCenterPage(),
  ];

  @override
  void initState() {
    super.initState();
    // 读完一章自动进入下一章
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsControllerProvider.notifier).onChapterCompleted(() {
        if (!mounted) return;
        _showToast('本章已读完，可在阅读页继续下一章');
      });
    });
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(libraryControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom + 66,
            child: MiniPlayer(
              onTap: () {
                if (books.isEmpty) {
                  _showToast('书架还没有书，先导入或添加一本书吧');
                  return;
                }
                showListenSheet(context, ref, books.first);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: '发现'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: '书架'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'AI 中心'),
        ],
      ),
    );
  }
}
