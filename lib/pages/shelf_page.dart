import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../data/models.dart';
import '../state/library_controller.dart';
import '../widgets/book_cover.dart';
import 'reader/reader_page.dart';

/// 书架页：入口卡片 + 书籍网格 + 本地导入
class ShelfPage extends ConsumerStatefulWidget {
  const ShelfPage({super.key});

  @override
  ConsumerState<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends ConsumerState<ShelfPage> {
  bool _grid = true;
  final TextEditingController _search = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final f in result.files) {
      final path = f.path;
      if (path == null) continue;
      try {
        await ref.read(libraryControllerProvider.notifier).importFile(path);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('《${f.name}》导入失败：$e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(libraryControllerProvider);
    final books = all
        .where((b) => _keyword.isEmpty || b.title.contains(_keyword) || b.author.contains(_keyword))
        .toList();
    final reading = all.where((b) => b.progress > 0 && b.progress < 1).toList();
    final favorites = all.where((b) => b.favorite).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('书架', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(() => _grid = !_grid),
                          icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _keyword = v.trim()),
                      decoration: const InputDecoration(
                        hintText: '在书架中搜索',
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textHint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 92,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FolderEntry(
                      icon: Icons.history_edu_rounded,
                      title: '继续阅读',
                      count: reading.length,
                      color: const Color(0xFF5B8DEF),
                      onTap: () => _openFirst(reading),
                    ),
                    _FolderEntry(
                      icon: Icons.favorite_rounded,
                      title: '我的收藏',
                      count: favorites.length,
                      color: const Color(0xFFEF6B8C),
                      onTap: () => _openFirst(favorites),
                    ),
                    _FolderEntry(
                      icon: Icons.file_upload_outlined,
                      title: '本地导入',
                      count: all.length,
                      color: const Color(0xFF3FB98B),
                      onTap: _import,
                    ),
                  ],
                ),
              ),
            ),
            if (books.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 56, color: AppColors.textHint),
                      SizedBox(height: 12),
                      Text('书架还是空的', style: TextStyle(color: AppColors.textSecondary)),
                      SizedBox(height: 6),
                      Text('点击下方按钮导入 TXT / EPUB', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else if (_grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BookGridItem(
                      book: books[i],
                      onTap: () => _open(books[i]),
                      onLongPress: () => _showMenu(books[i]),
                    ),
                    childCount: books.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.56,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _BookListItem(
                    book: books[i],
                    onTap: () => _open(books[i]),
                    onLongPress: () => _showMenu(books[i]),
                  ),
                  childCount: books.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _import,
        icon: const Icon(Icons.add_rounded),
        label: const Text('导入书籍'),
      ),
    );
  }

  Future<void> _open(Book book) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ReaderPage(book: book)),
    );
    ref.read(libraryControllerProvider.notifier).refresh();
  }

  void _openFirst(List<Book> list) {
    if (list.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('这里还没有书')));
      return;
    }
    _open(list.first);
  }

  void _showMenu(Book book) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: Text(book.favorite ? '取消收藏' : '加入收藏'),
              onTap: () {
                ref.read(libraryControllerProvider.notifier).toggleFavorite(book);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('从书架移除', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                ref.read(libraryControllerProvider.notifier).remove(book.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderEntry extends StatelessWidget {
  const _FolderEntry({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 118,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$count 本', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  const _BookGridItem({required this.book, required this.onTap, required this.onLongPress});

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              BookCover(
                title: book.title,
                author: book.author,
                gradientIndex: book.coverIndex,
                width: double.infinity,
                height: 128,
              ),
              if (book.favorite)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.favorite, size: 16, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(book.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: book.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 3,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 3),
          Text(book.progressText, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _BookListItem extends StatelessWidget {
  const _BookListItem({required this.book, required this.onTap, required this.onLongPress});

  final Book book;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: BookCover(
        title: book.title,
        author: book.author,
        gradientIndex: book.coverIndex,
        width: 48,
        height: 68,
        radius: 8,
      ),
      title: Text(book.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('${book.author} · ${book.format.label} · ${book.chapterCount} 章',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: book.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 3,
              backgroundColor: AppColors.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
      trailing: Text(book.progressText, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
    );
  }
}
