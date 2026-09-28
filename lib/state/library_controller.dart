import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/repositories.dart';
import '../data/storage/book_storage.dart';
import '../services/importer/book_importer.dart';

/// 书架状态
class LibraryController extends Notifier<List<Book>> {
  @override
  List<Book> build() {
    Future.microtask(refresh);
    return BookRepository.instance.all();
  }

  void refresh() {
    state = BookRepository.instance.all();
  }

  Future<Book> importFile(String path) async {
    final book = await BookImporter.instance.importFile(path);
    refresh();
    return book;
  }

  Future<void> remove(String id) async {
    await BookRepository.instance.remove(id);
    await BookStorage.deleteBook(id);
    refresh();
  }

  Future<void> toggleFavorite(Book book) async {
    book.favorite = !book.favorite;
    await BookRepository.instance.save(book);
    refresh();
  }

  Future<void> saveProgress(
    String id, {
    int? chapterIndex,
    int? pageIndex,
    double? progress,
  }) async {
    final book = BookRepository.instance.get(id);
    if (book == null) return;
    if (chapterIndex != null) book.chapterIndex = chapterIndex;
    if (pageIndex != null) book.pageIndex = pageIndex;
    if (progress != null) book.progress = progress.clamp(0.0, 1.0).toDouble();
    book.lastReadAt = DateTime.now();
    await BookRepository.instance.save(book);
    refresh();
  }
}

final libraryControllerProvider =
    NotifierProvider<LibraryController, List<Book>>(LibraryController.new);

/// 发现页内置的推荐书单（可替换为后端接口）
class RecommendBook {
  const RecommendBook(this.title, this.author, this.desc, this.category);

  final String title;
  final String author;
  final String desc;
  final String category;
}

const List<RecommendBook> recommendBooks = [
  RecommendBook('百年孤独', '加西亚·马尔克斯', '魔幻现实主义的巅峰之作，布恩迪亚家族七代人的孤独宿命。', '文学经典'),
  RecommendBook('人类简史', '尤瓦尔·赫拉利', '从认知革命到科学革命，重新理解我们何以成为今天的样子。', '人文社科'),
  RecommendBook('房思琪的初恋乐园', '林奕含', '一部用极致修辞写成的伤口之书，关于权力、语言与沉默。', '当代小说'),
  RecommendBook('沉默的大多数', '王小波', '以清醒与幽默抵抗愚昧，写给每一个不想被规训的人。', '杂文集'),
  RecommendBook('万历十五年', '黄仁宇', '一个平淡年份里，藏着大明帝国走向崩塌的全部伏笔。', '历史'),
  RecommendBook('苏东坡新传', '李一冰', '在贬谪与风波里，看一个灵魂如何活成中国文人的理想型。', '传记'),
];
