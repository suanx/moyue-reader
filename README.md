# 墨阅 Reader（Flutter）

一款以「白 + 浅蓝、大圆角、充足留白」为视觉基调的读书 App：支持本地 TXT / EPUB 导入、多引擎解析、竖排阅读、划线笔记，以及基于 **Edge-TTS（微软神经网络语音）+ 系统 TTS** 的双引擎听书。

## 一、功能与架构

```
发现页          书架页           阅读页            AI 中心
 ├ 搜索          ├ 继续阅读       ├ 精确分页        ├ 全书概要
 ├ 每日推荐      ├ 我的收藏       ├ 竖排（右起）    ├ 思维导图
 ├ 分类          ├ 本地导入       ├ 米黄/夜间背景   ├ 人物关系
 └ 新书速递      └ 网格/列表      └ 听书跟读        └ 金句摘录 + 问答

核心能力：本地书籍导入 · 多引擎解析(TXT/EPUB) · 阅读设置 · 划线笔记 · AI 四类生成 · Edge-TTS 听书
底层支撑：Riverpod(状态) · Hive(持久化) · Dio(网络) · just_audio + flutter_tts(音频) · archive/xml(解析)
```

## 二、目录结构

```
lib/
├─ main.dart                      入口（初始化 Hive 后启动）
├─ app.dart                       MaterialApp + 主题
├─ core/
│  ├─ theme/                      配色与主题（米黄纸感、蓝紫渐变）
│  └─ utils/pagination.dart       按屏幕尺寸精确分页（横排按行 / 竖排按列）
├─ data/
│  ├─ models.dart                 Book / Chapter / Note / AiMessage / TtsVoice
│  ├─ repositories.dart           BookRepository、NoteRepository
│  └─ storage/                    Hive 初始化、章节与 TTS 音频文件管理
├─ services/
│  ├─ parsers/                    txt_parser / epub_parser（多引擎解析）
│  ├─ importer/                   book_importer（导入落盘）、sample_books（内置示例书）
│  ├─ tts/
│  │  ├─ tts_engine.dart          引擎抽象、朗读参数、长文本切句
│  │  ├─ edge_tts_engine.dart     ★ Edge-TTS 协议实现（WSS + Sec-MS-GEC）
│  │  ├─ system_tts_engine.dart   系统离线 TTS 逐段朗读
│  │  └─ audio_book_player.dart   ★ 分句合成 + 缓存 + 无缝串播 + 预取
│  └─ ai/ai_service.dart          OpenAI 兼容接口 + 离线兜底
├─ state/                         Riverpod：library / reader / tts / settings
├─ pages/                         main_shell / discover / shelf / reader / ai
└─ widgets/                       book_cover / mini_player / vertical_text
```

## 三、Edge-TTS 实现要点

文件：`lib/services/tts/edge_tts_engine.dart`

1. **连接地址**
   `wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1`
   查询参数：`TrustedClientToken`、`Sec-MS-GEC`、`Sec-MS-GEC-Version`、`ConnectionId`
2. **Sec-MS-GEC 签名**（微软自 2023 年启用的 DRM）
   - 取当前 UTC 时间戳，加上 Windows 纪元偏移 `11644473600`
   - 截断到 5 分钟（300 秒）的整数倍，换算成 100ns 的 FILETIME
   - `SHA256(FILETIME + TrustedClientToken)`，结果转大写十六进制
3. **握手顺序**
   - 先发 `Path: speech.config`（指定 `audio-24khz-48kbitrate-mono-mp3`）
   - 再发 `Path: ssml`，SSML 里用 `<prosody rate pitch volume>` 控制语速语调
   - 二进制帧结构：`[2 字节头长度][头文本][MP3 数据]`，代码按此拆包
   - 收到 `Path: turn.end` 视为本段合成结束
4. **听书播放**（`audio_book_player.dart`）
   - 章节先按标点切成 ≤200 字的短句
   - 逐句合成并写入本地缓存（缓存键 = 音色 + 语速 + 文本 的 SHA1）
   - 用 `ConcatenatingAudioSource` 追加播放，实现**无缝串播**；播放当前句时后台预取下一句
   - 支持：播放/暂停/停止、跳句、变速（自动重合成当前句）、音色切换、定时关闭、自动连播下一章
5. **双引擎切换**：听书面板顶部可切换「Edge 在线语音」与「系统离线语音」，后者走 `flutter_tts`，断网也能听。

常用中文音色（内置）：`zh-CN-XiaoxiaoNeural` 晓晓、`zh-CN-YunxiNeural` 云希、`zh-CN-YunjianNeural` 云健（评书/小说）、`zh-CN-YunyangNeural` 云扬（播报）、`zh-CN-liaoning-XiaobeiNeural` 东北话、`zh-CN-shaanxi-XiaoniNeural` 陕西话、`zh-HK-HiuGaaiNeural` 粤语。联网时会自动拉取官方完整音色列表。

## 四、运行环境与打包

### 4.1 一键安装（推荐）

在有正常外网的机器上执行：

```bash
cd <项目目录>
./setup_env.sh              # 装 Flutter + Android SDK，并生成 android/ 目录、注入网络权限
./setup_env.sh --no-android # 只装 Flutter（可 analyze / test，不打 APK）
./setup_env.sh --cn         # 走国内镜像（storage.flutter-io.cn / pub.flutter-io.cn）
FLUTTER_VERSION=3.35.1 ./setup_env.sh
```

脚本会依次完成：系统依赖（JDK17 / git / unzip / mesa）→ Flutter SDK → Android SDK（platform-tools + platform-35 + build-tools-35）→ 写入 `~/.moyue_env` → 生成 `android/` → 注入 `INTERNET` 权限（Edge-TTS 与 AI 必需，官方模板默认没有）。

装好后：

```bash
source ~/.moyue_env
flutter pub get
flutter analyze            # 静态检查
flutter test               # 单元测试
flutter build apk --debug
flutter build apk --release
```

### 4.2 云端构建（推荐，无需本地环境）

仓库已内置 `.github/workflows/flutter-build.yml`：push 到 main 或发 PR 时自动跑 `analyze` → `test` → `build apk`，APK 在 Actions 产物里直接下载。

**完整步骤见 [`GITHUB_ACTIONS_GUIDE.md`](GITHUB_ACTIONS_GUIDE.md)**，概括起来三步：

```bash
git init && git add . && git commit -m "initial"      # 本仓库已初始化好，可跳过
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

然后去仓库的 **Actions** 页等 6–12 分钟，在页面底部 **Artifacts** 下载 `墨阅Reader-debug`。

CI 会自动完成三件容易漏的事（已实测）：生成 `android/` 平台目录、注入 `INTERNET` 权限（Edge-TTS 与 AI 必需，官方模板默认没有）、校验并按需提升 `minSdk` 到 23。

### 4.3 单元测试

```bash
flutter test
```

已覆盖：

| 测试文件 | 验证内容 |
|---|---|
| `test/tts_text_splitter_test.dart` | 长文本切句：中英标点、短句合并、无标点硬切、不丢字 |
| `test/edge_tts_engine_test.dart` | Sec-MS-GEC 为 64 位大写十六进制、WSS 参数齐全、中文音色列表 |
| `test/txt_parser_test.dart` | 「第X章」识别与分章、无章节时按字数切片、书名推断 |
| `test/paginator_test.dart` | 竖排分页连续无重叠无丢字、`TextPage.contains` 边界 |

### 4.4 语法自检（无 Flutter 时也能跑）

`tools/dart_syntax_check.py` 用 tree-sitter 的 Dart 语法解析器校验全部 `.dart` 文件，不需要 Flutter SDK：

```bash
pip install tree-sitter tree-sitter-dart
python3 tools/dart_syntax_check.py
```

> 它只能查语法（括号、结构），查不了类型和 API 用法——类型问题仍需 `flutter analyze`。

依赖（见 `pubspec.yaml`）：`flutter_riverpod`、`hive` + `hive_flutter`、`dio`、`web_socket_channel`、`crypto`、`uuid`、`flutter_tts`、`just_audio`、`audio_session`、`file_picker`、`path_provider`、`archive`、`xml`。

### 平台配置

- **Android**：`android/app/src/main/AndroidManifest.xml` 需有网络权限（Edge-TTS 与 AI 都要联网）
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  ```
  `setup_env.sh` 会自动注入；手动配置时注意加在 `<application>` 之前。
  EPUB 解析基于 Dart 解压，不额外申请存储权限（走系统文件选择器）。
- **iOS**：`ios/Runner/Info.plist` 建议开启后台音频
  ```xml
  <key>UIBackgroundModes</key><array><string>audio</string></array>
  ```
- **minSdkVersion**：`flutter_tts` / `just_audio` 建议 `android/app/build.gradle` 中 `minSdkVersion 23`。

## 五、AI 中心配置

默认未配置模型时会使用**本地离线分析**（章节概要、章节脑图、人物频次统计、金句抽取），保证功能可用。

想接真实模型：AI 中心右上角「⚙ 模型配置」填入任意 OpenAI 兼容接口，例如：

| 服务 | Base URL | 模型 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| 智谱 | `https://open.bigmodel.cn/api/paas/v4` | `glm-4-flash` |
| 本地 Ollama | `http://localhost:11434/v1` | `qwen2.5` |

配置保存在 Hive 的 `settings` Box 中。

## 六、使用小抄

1. **导入书**：书架页 →「导入书籍」→ 选择 `.txt` / `.epub`，自动切章、生成封面与字数统计。
2. **立刻体验**：发现页点「今日一书」或「新书速递」，会生成内置示例书（桃花源记 / 爱莲说 / 岳阳楼记 / 赤壁赋）并直接进入阅读页。
3. **听书**：阅读页点中部唤出菜单 →「听书」→ 选音色与语速 → 播放；也可在任何页面用底部悬浮条控制。
4. **竖排**：阅读页「设置」→ 打开「竖排阅读」，文字从右向左分列，适合古籍诗词。
5. **AI 解读**：阅读页顶部「AI 解读」可针对当前章节生成概要 / 脑图 / 人物 / 金句。

## 七、已知限制

- **沙盒内无法完成 Flutter 安装**：本机出网受白名单策略限制，以下必需源均不可达（HTTP 403 `policy_default_denied`）：
  `storage.googleapis.com`（Flutter SDK 与预编译 Dart SDK）、`pub.dev`（依赖包）、`dl.google.com`（Android SDK）。
  可连通的只有 `mirrors.cloud.tencent.com`、`codeload.github.com`、`api.github.com`——其中 Flutter 源码包不含 Dart SDK，仍需二次下载，因此无法引导出可用的 `flutter` 命令。
  磁盘（4.4 GB 可用）与内存（2.3 GB）也不足以承载 Flutter + Android SDK + Gradle。
  请使用 **4.1 一键安装脚本** 或在有外网的机器上执行，用 **4.2 GitHub Actions** 云端构建。
- TXT 默认按 UTF-8 解码；GBK 编码的中文 TXT 需接入编码转换（在 `BookStorage.decodeString` 替换实现，例如 `charset_converter`）后即可支持。
- 仅支持无 DRM 的标准 EPUB；加密或异常结构文件会提示解析失败。
- `just_audio` / `flutter_tts` 主要面向 Android / iOS / macOS，桌面端（Windows / Linux）听书能力受限。
- Edge-TTS 依赖微软在线服务，若所在网络无法访问 `speech.platform.bing.com`，请改用「系统离线语音」引擎。
