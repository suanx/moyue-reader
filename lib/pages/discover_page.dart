import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../services/importer/sample_books.dart';
import '../state/library_controller.dart';
import '../widgets/book_cover.dart';
import 'reader/reader_page.dart';

/// 发现页：搜索、每日推荐、分类、新书速递
class DiscoverPage extends ConsumerStatefulWidget {
  const DiscoverPage({super.key});

  @override
  ConsumerState<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends ConsumerState<DiscoverPage> {
  final TextEditingController _search = TextEditingController();
  String _keyword = '';
  int _category = 0;

  static const List<String> _categories = ['全部', '文学', '历史', '社科', '科幻'];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openSample(Map<String, String> sample) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final book = await SampleBooks.create(
        sample['title']!,
        sample['author']!,
        sample['desc']!,
      );
      ref.read(libraryControllerProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReaderPage(book: book)),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('打开失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final samples = SampleBooks.samples
        .where((s) => _keyword.isEmpty || s['title']!.contains(_keyword))
        .toList();

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
                    const Text('发现', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _keyword = v.trim()),
                      decoration: InputDecoration(
                        hintText: '搜索书名、作者或关键词',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint),
                        suffixIcon: _keyword.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _keyword = '');
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 每日推荐
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                child: Row(
                  children: const [
                    Text('每日推荐', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Spacer(),
                    Text('换一批', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DailyCard(onTap: () => _openSample(SampleBooks.samples.first)),
              ),
            ),
            // 分类
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) => ChoiceChip(
                    label: Text(_categories[i]),
                    selected: _category == i,
                    onSelected: (_) => setState(() => _category = i),
                    showCheckmark: false,
                  ),
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemCount: _categories.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Row(
                  children: const [
                    Text('新书速递', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 168,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: samples.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) {
                    final s = samples[i];
                    return _NewBookCard(
                      title: s['title']!,
                      author: s['author']!,
                      desc: s['desc']!,
                      index: i,
                      onTap: () => _openSample(s),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: const [
                    Text('阅读榜单', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final b = recommendBooks[i % recommendBooks.length];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: BookCover(
                      title: b.title,
                      author: b.author,
                      gradientIndex: i % 6,
                      width: 44,
                      height: 62,
                      radius: 8,
                    ),
                    title: Text(b.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${b.category} · ${b.author}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
                    onTap: () => _openSample({
                      'title': SampleBooks.samples[i % SampleBooks.samples.length]['title']!,
                      'author': SampleBooks.samples[i % SampleBooks.samples.length]['author']!,
                      'desc': b.desc,
                    }),
                  );
                },
                childCount: recommendBooks.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 168,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x2E5B8DEF), blurRadius: 18, offset: Offset(0, 8)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('今日一书', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '桃花源记',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '陶渊明 · 东晋',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const Spacer(),
                  const Text(
                    '「不足为外人道也。」',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            BookCover(
              title: '桃花源记',
              author: '陶渊明',
              gradientIndex: 3,
              width: 92,
              height: 128,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewBookCard extends StatelessWidget {
  const _NewBookCard({
    required this.title,
    required this.author,
    required this.desc,
    required this.index,
    required this.onTap,
  });

  final String title;
  final String author;
  final String desc;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(title: title, author: author, gradientIndex: index, width: 132, height: 118),
            const SizedBox(height: 8),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
