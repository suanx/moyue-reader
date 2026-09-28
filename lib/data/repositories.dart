import 'package:moyue_reader/data/models.dart';
import 'package:moyue_reader/data/storage/app_database.dart';

/// 书架数据仓库
class BookRepository {
  BookRepository._();

  static final BookRepository instance = BookRepository._();

  List<Book> all() {
    final list = AppDatabase.books().values
        .map((e) => Book.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }

  Book? get(String id) {
    final raw = AppDatabase.books().get(id);
    if (raw == null) return null;
    return Book.fromJson(Map<dynamic, dynamic>.from(raw as Map));
  }

  Future<void> save(Book book) => AppDatabase.books().put(book.id, book.toJson());

  Future<void> remove(String id) => AppDatabase.books().delete(id);
}

/// 划线 / 笔记 / 书签仓库
class NoteRepository {
  NoteRepository._();

  static final NoteRepository instance = NoteRepository._();

  List<Note> ofBook(String bookId) {
    final list = AppDatabase.notes()
        .values
        .map((e) => Note.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .where((n) => n.bookId == bookId)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> save(Note note) => AppDatabase.notes().put(note.id, note.toJson());

  Future<void> remove(String id) => AppDatabase.notes().delete(id);
}
