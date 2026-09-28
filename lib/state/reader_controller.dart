import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/pagination.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../data/storage/book_storage.dart';
import 'library_controller.dart';

/// 阅读会话状态
class ReaderState {
  const ReaderState({
    required this.book,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.content,
    this.pages = const [],
    this.pageIndex = 0,
    this.loading = false,
  });

  final Book book;
  final int chapterIndex;
  final String chapterTitle;
  final String content;
  final List<TextPage> pages;
  final int pageIndex;
  final bool loading;

  int get pageCount => pages.isEmpty ? 1 : pages.length;

  String get pageLabel => '${pageIndex + 1}/$pageCount';

  ReaderState copyWith({
    Book? book,
    int? chapterIndex,
    String? chapterTitle,
    String? content,
    List<TextPage>? pages,
    int? pageIndex,
    bool? loading,
  }) =>
      ReaderState(
        book: book ?? this.book,
        chapterIndex: chapterIndex ?? this.chapterIndex,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        content: content ?? this.content,
        pages: pages ?? this.pages,
        pageIndex: pageIndex ?? this.pageIndex,
        loading: loading ?? this.loading,
      );
}

/// 阅读控制器：负责章节加载、分页计算与进度保存
class ReaderController extends Notifier<ReaderState?> {
  @override
  ReaderState? build() => null;

  Future<void> open(Book book, {int? chapterIndex, int? pageIndex}) async {
    final maxChapter = book.chapterCount <= 0 ? 0 : book.chapterCount - 1;
    final index = ((chapterIndex ?? book.chapterIndex).clamp(0, maxChapter)).toInt();
    state = ReaderState(
      book: book,
      chapterIndex: index,
      chapterTitle: book.chapterTitles.isEmpty ? '全文' : book.chapterTitles[index],
      content: '',
      pageIndex: pageIndex ?? 0,
      loading: true,
    );
    await _loadChapter(index, keepPage: pageIndex ?? 0);
  }

  Future<void> goToChapter(int index) async {
    final s = state;
    if (s == null) return;
    final maxChapter = s.book.chapterCount <= 0 ? 0 : s.book.chapterCount - 1;
    final clamped = index.clamp(0, maxChapter).toInt();
    if (clamped == s.chapterIndex && s.content.isNotEmpty) return;
    await _loadChapter(clamped, keepPage: 0);
    await _saveProgress();
  }

  Future<void> _loadChapter(int index, {int keepPage = 0}) async {
    final s = state;
    if (s == null) return;
    final fileName = BookStorage.encodeChapterFileName(index);
    final content = await BookStorage.readChapter(s.book.id, fileName);
    state = s.copyWith(
      chapterIndex: index,
      chapterTitle: index < s.book.chapterTitles.length ? s.book.chapterTitles[index] : '第 ${index + 1} 章',
      content: content,
      pages: const [],
      pageIndex: keepPage,
      loading: false,
    );
  }

  /// 由 UI 在拿到布局尺寸后写入分页结果
  void applyPages(List<TextPage> pages) {
    final s = state;
    if (s == null || pages.isEmpty) return;
    final pageIndex = s.pageIndex.clamp(0, pages.length - 1).toInt();
    state = s.copyWith(pages: pages, pageIndex: pageIndex);
  }

  Future<void> setPage(int pageIndex) async {
    final s = state;
    if (s == null) return;
    state = s.copyWith(pageIndex: pageIndex.clamp(0, s.pageCount - 1).toInt());
    await _saveProgress();
  }

  Future<void> _saveProgress() async {
    final s = state;
    if (s == null) return;
    final chapterRatio = s.pageCount <= 1 ? 1 : (s.pageIndex + 1) / s.pageCount;
    final progress = s.book.chapterCount <= 1
        ? chapterRatio
        : ((s.chapterIndex + chapterRatio) / s.book.chapterCount).clamp(0.0, 1.0).toDouble();
    await ref.read(libraryControllerProvider.notifier).saveProgress(
          s.book.id,
          chapterIndex: s.chapterIndex,
          pageIndex: s.pageIndex,
          progress: progress,
        );
  }

  /// 划线 / 笔记
  Future<void> addNote(NoteType type, String quote, {String? comment}) async {
    final s = state;
    if (s == null || quote.trim().isEmpty) return;
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      bookId: s.book.id,
      type: type,
      chapterIndex: s.chapterIndex,
      quote: quote.trim(),
      comment: comment,
      createdAt: DateTime.now(),
    );
    await NoteRepository.instance.save(note);
  }

  Future<void> toggleBookmark() async {
    final s = state;
    if (s == null || s.pages.isEmpty) return;
    final quote = s.pages[s.pageIndex].text;
    final existing = NoteRepository.instance
        .ofBook(s.book.id)
        .where((n) => n.type == NoteType.bookmark && n.chapterIndex == s.chapterIndex && n.quote == quote);
    if (existing.isNotEmpty) {
      await NoteRepository.instance.remove(existing.first.id);
    } else {
      await addNote(NoteType.bookmark, quote);
    }
  }
}

final readerControllerProvider =
    NotifierProvider<ReaderController, ReaderState?>(ReaderController.new);
