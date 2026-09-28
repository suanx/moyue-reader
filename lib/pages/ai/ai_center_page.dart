import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../data/storage/book_storage.dart';
import '../../services/ai/ai_service.dart';
import '../../state/library_controller.dart';

/// AI 中心：概要 / 思维导图 / 人物关系 / 金句摘录 + 自由问答
class AiCenterPage extends ConsumerStatefulWidget {
  const AiCenterPage({super.key});

  @override
  ConsumerState<AiCenterPage> createState() => _AiCenterPageState();
}

class _AiCenterPageState extends ConsumerState<AiCenterPage> {
  final TextEditingController _ask = TextEditingController();
  Book? _selected;
  String _result = '';
  bool _loading = false;
  String _title = '';
  final List<AiMessage> _chat = [];

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  Future<void> _run(AiKind kind, String label) async {
    final book = _selected;
    if (book == null) {
      _toast('请先选择一本书');
      return;
    }
    setState(() {
      _loading = true;
      _title = label;
      _result = '';
    });
    final text = await AiService.instance.generate(kind, book, await _content(book));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = text;
    });
  }

  Future<String> _content(Book book) async {
    final buffer = StringBuffer();
    for (var i = 0; i < book.chapterCount && i < 5; i++) {
      buffer.writeln(
        await BookStorage.readChapter(book.id, BookStorage.encodeChapterFileName(i)),
      );
    }
    return buffer.toString();
  }

  Future<void> _send() async {
    final text = _ask.text.trim();
    if (text.isEmpty) return;
    final book = _selected;
    setState(() {
      _chat.add(AiMessage(role: AiRole.user, content: text, createdAt: DateTime.now()));
      _chat.add(AiMessage(
        role: AiRole.assistant,
        content: '',
        createdAt: DateTime.now(),
        pending: true,
      ));
    });
    _ask.clear();
    final contextText = book == null ? '' : await _content(book);
    final prompt = book == null
        ? text
        : '书名：${book.title}（${book.author}）\n正文节选：\n$contextText\n\n读者提问：$text';
    final answer = await AiService.instance.chat([
      (role: 'system', content: '你是阅读助手，回答简洁、有依据，中文输出。'),
      (role: 'user', content: prompt),
    ]);
    if (!mounted) return;
    setState(() {
      _chat.removeLast();
      _chat.add(AiMessage(role: AiRole.assistant, content: answer, createdAt: DateTime.now()));
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(libraryControllerProvider);
    if (_selected == null && books.isNotEmpty) _selected = books.first;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  const Text('AI 中心', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showConfig(context),
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: '模型配置',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: DropdownButtonFormField<Book>(
                initialValue: books.contains(_selected) ? _selected : null,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.menu_book_outlined, color: AppColors.textHint),
                  hintText: books.isEmpty ? '书架还没有书' : '选择书籍',
                ),
                items: books
                    .map((b) => DropdownMenuItem<Book>(
                          value: b,
                          child: Text('《${b.title}》· ${b.author}', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (b) => setState(() => _selected = b),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _AiCard(icon: Icons.summarize_outlined, label: '全书概要', color: const Color(0xFF5B8DEF), onTap: () => _run(AiKind.summary, '全书概要')),
                  const SizedBox(width: 12),
                  _AiCard(icon: Icons.account_tree_outlined, label: '思维导图', color: const Color(0xFF7B6CF6), onTap: () => _run(AiKind.mindmap, '思维导图')),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _AiCard(icon: Icons.people_outline, label: '人物关系', color: const Color(0xFFEF6B8C), onTap: () => _run(AiKind.characters, '人物关系')),
                  const SizedBox(width: 12),
                  _AiCard(icon: Icons.format_quote_rounded, label: '金句摘录', color: const Color(0xFF3FB98B), onTap: () => _run(AiKind.quotes, '金句摘录')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            : Text(
                                _result.isEmpty
                                    ? '选择上方任意一种 AI 能力，或在下方直接提问。\n未配置模型时会自动使用本地离线分析。'
                                    : _result,
                                style: const TextStyle(fontSize: 14, height: 1.7),
                              ),
                      ),
                    ),
                    if (_chat.isNotEmpty) const Divider(height: 20),
                    if (_chat.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _chat.length,
                          itemBuilder: (context, i) {
                            final m = _chat[i];
                            final isUser = m.role == AiRole.user;
                            return Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isUser ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF1F4FA),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  m.pending ? '思考中…' : m.content,
                                  style: const TextStyle(fontSize: 13, height: 1.5),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _ask,
                            decoration: const InputDecoration(
                              hintText: '就这本书问点什么…',
                              isDense: true,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _showConfig(BuildContext context) async {
    final urlCtrl = TextEditingController(text: AiService.baseUrl);
    final keyCtrl = TextEditingController(text: AiService.apiKey);
    final modelCtrl = TextEditingController(text: AiService.model);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 模型配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('兼容 OpenAI 接口，例如 DeepSeek、通义千问、智谱、本地 Ollama',
                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            const SizedBox(height: 14),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Base URL', hintText: 'https://api.deepseek.com/v1')),
            const SizedBox(height: 10),
            TextField(controller: keyCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'API Key')),
            const SizedBox(height: 10),
            TextField(controller: modelCtrl, decoration: const InputDecoration(labelText: '模型名', hintText: 'deepseek-chat')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await AiService.saveConfig(
                  url: urlCtrl.text.trim(),
                  key: keyCtrl.text.trim(),
                  modelName: modelCtrl.text.trim().isEmpty ? 'deepseek-chat' : modelCtrl.text.trim(),
                );
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) _toast('已保存模型配置');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.icon, required this.label, required this.color, required this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
