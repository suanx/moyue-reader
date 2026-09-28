import 'dart:convert';

/// 支持的书籍格式（多引擎解析）
enum BookFormat { txt, epub }

extension BookFormatX on BookFormat {
  String get label => switch (this) {
        BookFormat.txt => 'TXT',
        BookFormat.epub => 'EPUB',
      };
}

/// 一本书的元数据。正文按章节切片后存于私有目录，本体不入库，保证轻快。
class Book {
  Book({
    required this.id,
    required this.title,
    required this.author,
    required this.format,
    required this.addedAt,
    this.coverIndex = 0,
    this.coverUrl,
    this.description = '',
    this.charCount = 0,
    this.chapterTitles = const [],
    this.lastReadAt,
    this.chapterIndex = 0,
    this.pageIndex = 0,
    this.progress = 0,
    this.favorite = false,
    this.category = '默认书架',
  });

  final String id;
  String title;
  String author;
  final BookFormat format;
  final DateTime addedAt;

  /// 占位封面渐变索引（0-5）
  final int coverIndex;
  final String? coverUrl;
  String description;
  int charCount;
  List<String> chapterTitles;

  DateTime? lastReadAt;
  int chapterIndex;
  int pageIndex;
  double progress;
  bool favorite;
  String category;

  int get chapterCount => chapterTitles.length;

  String get progressText => '${(progress * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'format': format.name,
        'addedAt': addedAt.toIso8601String(),
        'coverIndex': coverIndex,
        'coverUrl': coverUrl,
        'description': description,
        'charCount': charCount,
        'chapterTitles': chapterTitles,
        'lastReadAt': lastReadAt?.toIso8601String(),
        'chapterIndex': chapterIndex,
        'pageIndex': pageIndex,
        'progress': progress,
        'favorite': favorite,
        'category': category,
      };

  factory Book.fromJson(Map<dynamic, dynamic> json) => Book(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '未命名',
        author: (json['author'] as String?) ?? '佚名',
        format: BookFormat.values.firstWhere(
          (e) => e.name == (json['format'] ?? 'txt'),
          orElse: () => BookFormat.txt,
        ),
        addedAt: DateTime.tryParse((json['addedAt'] as String?) ?? '') ?? DateTime.now(),
        coverIndex: (json['coverIndex'] as num?)?.toInt() ?? 0,
        coverUrl: json['coverUrl'] as String?,
        description: (json['description'] as String?) ?? '',
        charCount: (json['charCount'] as num?)?.toInt() ?? 0,
        chapterTitles: ((json['chapterTitles'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        lastReadAt: DateTime.tryParse((json['lastReadAt'] as String?) ?? ''),
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        favorite: (json['favorite'] as bool?) ?? false,
        category: (json['category'] as String?) ?? '默认书架',
      );

  Book copy() => Book.fromJson(jsonDecode(jsonEncode(toJson())));
}

/// 章节（正文按 chapter 文件切片存放）
class Chapter {
  const Chapter({
    required this.index,
    required this.title,
    required this.fileName,
    this.length = 0,
  });

  final int index;
  final String title;
  final String fileName;
  final int length;
}

enum NoteType { highlight, note, bookmark }

/// 划线 / 笔记 / 书签
class Note {
  Note({
    required this.id,
    required this.bookId,
    required this.type,
    required this.chapterIndex,
    required this.quote,
    this.comment,
    this.colorValue = 0xFFFFE9A8,
    required this.createdAt,
  });

  final String id;
  final String bookId;
  final NoteType type;
  final int chapterIndex;
  final String quote;
  String? comment;
  int colorValue;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookId': bookId,
        'type': type.name,
        'chapterIndex': chapterIndex,
        'quote': quote,
        'comment': comment,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Note.fromJson(Map<dynamic, dynamic> json) => Note(
        id: json['id'] as String,
        bookId: json['bookId'] as String,
        type: NoteType.values.firstWhere(
          (e) => e.name == (json['type'] ?? 'highlight'),
          orElse: () => NoteType.highlight,
        ),
        chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
        quote: (json['quote'] as String?) ?? '',
        comment: json['comment'] as String?,
        colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFFFFE9A8,
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      );
}

enum AiRole { user, assistant }

enum AiKind { summary, mindmap, characters, quotes, chat }

class AiMessage {
  AiMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.kind = AiKind.chat,
    this.pending = false,
  });

  final AiRole role;
  final String content;
  final DateTime createdAt;
  final AiKind kind;
  bool pending;
}

/// Edge-TTS / 系统 TTS 的音色
class TtsVoice {
  const TtsVoice({
    required this.shortName,
    required this.displayName,
    required this.locale,
    required this.gender,
  });

  final String shortName;
  final String displayName;
  final String locale;
  final String gender;

  bool get isChinese => locale.toLowerCase().startsWith('zh');
}
