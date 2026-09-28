import 'package:dio/dio.dart';

import '../../data/models.dart';
import '../../data/storage/app_database.dart';

/// AI 中心：支持任意 OpenAI 兼容接口（DeepSeek / 通义 / 智谱 / OpenAI / 本地 Ollama 等）。
/// 未配置密钥时自动降级为本地启发式分析，保证功能可用。
class AiService {
  AiService._();

  static final AiService instance = AiService._();
  static final Dio _dio = Dio();

  static String get baseUrl =>
      (AppDatabase.settings().get('ai_base_url') as String?) ?? '';
  static String get apiKey =>
      (AppDatabase.settings().get('ai_api_key') as String?) ?? '';
  static String get model =>
      (AppDatabase.settings().get('ai_model') as String?) ?? 'deepseek-chat';

  static bool get configured => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  static Future<void> saveConfig({String? url, String? key, String? modelName}) async {
    final box = AppDatabase.settings();
    if (url != null) await box.put('ai_base_url', url);
    if (key != null) await box.put('ai_api_key', key);
    if (modelName != null) await box.put('ai_model', modelName);
  }

  Future<String> chat(List<({String role, String content})> messages) async {
    if (!configured) {
      return '尚未配置 AI 接口。可在「AI 中心 → 右上角设置」填入 OpenAI 兼容的 Base URL 与 API Key（如 DeepSeek、通义千问、本地 Ollama）。';
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 90),
        ),
        data: {
          'model': model,
          'messages': messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(growable: false),
          'temperature': 0.6,
        },
      );
      final choices = res.data?['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return '模型未返回内容';
      final first = choices.first as Map<String, dynamic>;
      final message = first['message'] as Map<String, dynamic>?;
      return ((message?['content'] ?? '') as String).trim();
    } on DioException catch (e) {
      return 'AI 请求失败：${e.message ?? e.type}';
    } catch (e) {
      return 'AI 请求失败：$e';
    }
  }

  Future<String> generate(AiKind kind, Book book, String text) async {
    final clipped = text.length > 6000 ? text.substring(0, 6000) : text;
    final prompt = switch (kind) {
      AiKind.summary =>
        '请为《${book.title}》（作者：${book.author}）写一段 200 字以内的全书概要，包含核心内容与阅读价值，不要剧透结局。',
      AiKind.mindmap =>
        '请把下面内容整理成 Markdown 多层列表形式的思维导图，根节点是书名，层级不超过 3 层。',
      AiKind.characters =>
        '请提炼本书主要人物，用「人物 —— 身份/性格 —— 关键关系」的列表形式输出，不超过 8 人。',
      AiKind.quotes =>
        '请从下面内容中挑选 5 句最有价值的金句，逐条列出原文并附一句点评。',
      AiKind.chat => '请基于这本书的内容回答读者的问题。',
    };

    if (kind == AiKind.chat) return chat([(role: 'user', content: clipped)]);

    if (!configured) return _offline(kind, book, text);

    return chat([
      (
        role: 'system',
        content: '你是一名专业的阅读助理，回答使用中文，结构清晰，尽量使用 Markdown。'
      ),
      (role: 'user', content: '$prompt\n\n书名：${book.title}\n作者：${book.author}\n正文节选：\n$clipped'),
    ]);
  }

  /// 离线兜底：不依赖任何外部服务
  String _offline(AiKind kind, Book book, String text) {
    switch (kind) {
      case AiKind.summary:
        final plain = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        final head = plain.length > 200 ? plain.substring(0, 200) : plain;
        return '《${book.title}》· ${book.author}\n'
            '共 ${book.chapterCount} 章，约 ${(book.charCount / 10000).toStringAsFixed(1)} 万字。\n\n'
            '开篇：$head…\n\n'
            '（当前为离线概要，配置 AI 接口后可生成深度摘要。）';
      case AiKind.mindmap:
        final titles = book.chapterTitles.take(12).toList();
        return '- **${book.title}**\n'
            '${titles.map((t) => '  - $t').join('\n')}\n'
            '${book.chapterCount > 12 ? '  - …… 其余 ${book.chapterCount - 12} 章' : ''}';
      case AiKind.characters:
        return _extractCharacters(text);
      case AiKind.quotes:
        return _extractQuotes(text);
      case AiKind.chat:
        return '尚未配置 AI 接口，无法进行自由问答。';
    }
  }

  String _extractCharacters(String text) {
    final regex = RegExp(r'([\u4e00-\u9fa5]{2,4})(?:说|道|问|答|笑|喝|叹|应|摇头|点头|心中暗想)');
    final counter = <String, int>{};
    for (final m in regex.allMatches(text)) {
      final name = m.group(1)!;
      if (_stopWords.contains(name)) continue;
      counter[name] = (counter[name] ?? 0) + 1;
    }
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) {
      return '未能自动识别人物，配置 AI 接口后可获得更准确的人物关系图谱。';
    }
    return sorted
        .take(8)
        .map((e) => '- **${e.key}** —— 出现 ${e.value} 次')
        .join('\n');
  }

  String _extractQuotes(String text) {
    final sentences = text
        .split(RegExp(r'[。！？\n]'))
        .map((e) => e.trim())
        .where((e) => e.length >= 16 && e.length <= 60)
        .toList();
    if (sentences.isEmpty) return '这本书暂未抽取到金句。';
    sentences.shuffle();
    return sentences
        .take(5)
        .map((e) => '> $e。')
        .join('\n\n');
  }

  static const Set<String> _stopWords = {
    '他们', '我们', '你们', '自己', '没有', '什么', '怎么', '一个', '这个',
    '那个', '于是', '不过', '只是', '就是', '却是', '说道', '问道', '心中',
  };
}
