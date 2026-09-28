import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/io.dart';

import '../../data/models.dart';
import 'tts_engine.dart';

/// 微软 Edge 朗读服务（edge-tts）的 Dart 实现。
///
/// 协议要点：
/// 1. wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1
/// 2. 必须携带 Sec-MS-GEC 签名 = SHA256(WindowsFileTime(截断到 5 分钟) + TrustedClientToken)
/// 3. 先发 speech.config（指定输出格式），再发 SSML
/// 4. 二进制帧结构：[2 字节头长度][头文本][mp3 数据]
class EdgeTtsEngine implements SynthesisTtsEngine {
  EdgeTtsEngine({Dio? dio}) : _dio = dio ?? Dio();

  static const String _host = 'speech.platform.bing.com';
  static const String _path = '/consumer/speech/synthesize/readaloud/edge/v1';
  static const String _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _secMsGecVersion = '1-130.0.2849.68';
  static const String _origin = 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfoldm';
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/130.0.0.0 Safari/537.36 Edg/130.0.2849.68';
  static const String _outputFormat = 'audio-24khz-48kbitrate-mono-mp3';

  static const int _winEpoch = 11644473600; // 1601-01-01 → 1970-01-01（秒）
  static const int _ticksPerSecond = 10000000; // 100ns ticks

  final Dio _dio;
  final Uuid _uuid = const Uuid();

  static const List<TtsVoice> _fallbackVoices = [
    TtsVoice(shortName: 'zh-CN-XiaoxiaoNeural', displayName: '晓晓 · 温柔女声', locale: 'zh-CN', gender: 'Female'),
    TtsVoice(shortName: 'zh-CN-YunxiNeural', displayName: '云希 · 清朗男声', locale: 'zh-CN', gender: 'Male'),
    TtsVoice(shortName: 'zh-CN-YunjianNeural', displayName: '云健 · 评书小说', locale: 'zh-CN', gender: 'Male'),
    TtsVoice(shortName: 'zh-CN-YunyangNeural', displayName: '云扬 · 新闻播报', locale: 'zh-CN', gender: 'Male'),
    TtsVoice(shortName: 'zh-CN-XiaoyiNeural', displayName: '晓伊 · 活泼女声', locale: 'zh-CN', gender: 'Female'),
    TtsVoice(shortName: 'zh-CN-YunxiaNeural', displayName: '云夏 · 少年音', locale: 'zh-CN', gender: 'Male'),
    TtsVoice(shortName: 'zh-CN-liaoning-XiaobeiNeural', displayName: '晓北 · 东北话', locale: 'zh-CN', gender: 'Female'),
    TtsVoice(shortName: 'zh-CN-shaanxi-XiaoniNeural', displayName: '晓妮 · 陕西话', locale: 'zh-CN', gender: 'Female'),
    TtsVoice(shortName: 'zh-HK-HiuGaaiNeural', displayName: '曉佳 · 粤语', locale: 'zh-HK', gender: 'Female'),
    TtsVoice(shortName: 'zh-TW-HsiaoChenNeural', displayName: '曉臻 · 台湾', locale: 'zh-TW', gender: 'Female'),
    TtsVoice(shortName: 'en-US-AriaNeural', displayName: 'Aria · English', locale: 'en-US', gender: 'Female'),
    TtsVoice(shortName: 'en-US-GuyNeural', displayName: 'Guy · English', locale: 'en-US', gender: 'Male'),
    TtsVoice(shortName: 'ja-JP-NanamiNeural', displayName: '七海 · 日本語', locale: 'ja-JP', gender: 'Female'),
  ];

  /// 生成 Sec-MS-GEC：把 Windows FILETIME 截断到 5 分钟，再拼接 Token 做 SHA256
  String generateSecMsGec() {
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch / 1000.0;
    var ticks = nowSeconds + _winEpoch;
    ticks = ticks - (ticks % 300);
    final fileTime = (ticks * _ticksPerSecond).round();
    final digest = sha256.convert(utf8.encode('$fileTime$_trustedClientToken'));
    return digest.toString().toUpperCase();
  }

  Uri buildUri() {
    final gec = generateSecMsGec();
    final connectionId = _uuid.v4().replaceAll('-', '');
    return Uri(
      scheme: 'wss',
      host: _host,
      path: _path,
      queryParameters: {
        'TrustedClientToken': _trustedClientToken,
        'Sec-MS-GEC': gec,
        'Sec-MS-GEC-Version': _secMsGecVersion,
        'ConnectionId': connectionId,
      },
    );
  }

  Map<String, dynamic> get _headers => {
        'Pragma': 'no-cache',
        'Cache-Control': 'no-cache',
        'Origin': _origin,
        'Accept-Encoding': 'gzip, deflate, br',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Sec-WebSocket-Extensions': 'permessage-deflate; client_max_window_bits=15',
        'User-Agent': _userAgent,
      };

  @override
  Future<List<TtsVoice>> voices() async {
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://$_host/consumer/speech/synthesize/readaloud/voices/list',
        queryParameters: {'trustedclienttoken': _trustedClientToken},
        options: Options(
          headers: {'User-Agent': _userAgent, 'Origin': _origin},
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final data = res.data ?? const [];
      final list = data
          .whereType<Map<String, dynamic>>()
          .map(
            (e) => TtsVoice(
              shortName: (e['ShortName'] ?? '').toString(),
              displayName: (e['FriendlyName'] ?? e['ShortName'] ?? '').toString(),
              locale: (e['Locale'] ?? '').toString(),
              gender: (e['Gender'] ?? '').toString(),
            ),
          )
          .where((v) => v.shortName.isNotEmpty)
          .toList();
      if (list.isNotEmpty) {
        list.sort((a, b) {
          final ca = a.isChinese ? 0 : 1;
          final cb = b.isChinese ? 0 : 1;
          return ca != cb ? ca.compareTo(cb) : a.displayName.compareTo(b.displayName);
        });
        return list;
      }
    } catch (_) {
      // 网络不可用时回退内置列表
    }
    return _fallbackVoices;
  }

  /// 合成一段文本，返回 mp3 字节
  @override
  Future<Uint8List> synthesize(
    String text, {
    required TtsVoice voice,
    double rate = 1.0,
    double pitch = 1.0,
    double volume = 1.0,
  }) async {
    final uri = buildUri();
    final channel = IOWebSocketChannel.connect(uri, headers: _headers);
    final audio = BytesBuilder(copy: false);

    try {
      await channel.ready.timeout(const Duration(seconds: 10));

      final completer = Completer<Uint8List>();
      late StreamSubscription<dynamic> sub;

      void finish([Object? error]) {
        if (completer.isCompleted) return;
        if (error != null) {
          completer.completeError(error);
        } else {
          completer.complete(audio.takeBytes());
        }
      }

      sub = channel.stream.listen(
        (message) {
          if (message is List<int>) {
            final data = message is Uint8List ? message : Uint8List.fromList(message);
            _collectAudio(data, audio);
            return;
          }
          if (message is String) {
            if (message.contains('Path:turn.end') || message.contains('Path: audio.turn.end')) {
              finish();
            } else if (message.contains('Path:synthesis.context') == false &&
                message.contains('Path:audio.metadata') == false &&
                message.contains('Path:error')) {
              finish(Exception('Edge-TTS 返回错误：$message'));
            }
          }
        },
        onError: (Object e) => finish(e),
        onDone: () => finish(),
        cancelOnError: true,
      );

      channel.sink.add(_configPayload());
      channel.sink.add(_ssmlPayload(text, voice, rate, pitch, volume));

      final bytes = await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('Edge-TTS 合成超时'),
      );
      if (bytes.isEmpty) throw Exception('Edge-TTS 未返回音频数据');
      await sub.cancel();
      return bytes;
    } finally {
      try {
        await channel.sink.close();
      } catch (_) {}
    }
  }

  /// 解析二进制帧：前 2 字节为头长度，其后是音频负载
  void _collectAudio(Uint8List data, BytesBuilder audio) {
    if (data.length <= 2) return;
    final headerLength = (data[0] << 8) | data[1];
    final start = 2 + headerLength;
    if (start >= data.length) return;
    audio.add(data.sublist(start));
  }

  String _configPayload() {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final json = jsonEncode({
      'context': {
        'synthesis': {
          'audio': {
            'metadataoptions': {
              'sentenceBoundaryEnabled': false,
              'wordBoundaryEnabled': true,
            },
            'outputFormat': _outputFormat,
          },
        },
      },
    });
    return 'X-Timestamp:$timestamp\r\n'
        'Content-Type:application/json; charset=utf-8\r\n'
        'Path:speech.config\r\n\r\n$json';
  }

  String _ssmlPayload(
    String text,
    TtsVoice voice,
    double rate,
    double pitch,
    double volume,
  ) {
    final ratePercent = _signedPercent(rate);
    final pitchHz = _signedHz(pitch);
    final volumePercent = _signedPercent(volume);
    final ssml = '<speak version=\'1.0\' xmlns=\'http://www.w3.org/2001/10/synthesis\' '
        "xml:lang='${voice.locale}'>"
        "<voice name='${voice.shortName}'>"
        "<prosody rate='$ratePercent' pitch='$pitchHz' volume='$volumePercent'>"
        '${_escapeXml(text)}'
        '</prosody></voice></speak>';

    final requestId = _uuid.v4().replaceAll('-', '');
    final timestamp = DateTime.now().toUtc().toIso8601String();
    return 'X-RequestId:$requestId\r\n'
        'X-Timestamp:$timestamp\r\n'
        'Content-Type:application/ssml+xml\r\n'
        'Path:ssml\r\n\r\n$ssml';
  }

  String _signedPercent(double value) {
    final v = ((value - 1.0) * 100).round();
    return v >= 0 ? '+$v%' : '$v%';
  }

  String _signedHz(double value) {
    final v = ((value - 1.0) * 50).round();
    return v >= 0 ? '+${v}Hz' : '${v}Hz';
  }

  String _escapeXml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

/// 便于排查：单独跑一次签名验证
Future<String> debugSecMsGec() async => EdgeTtsEngine().generateSecMsGec();

/// 便于排查：设备是否可直连 Edge 服务
Future<bool> edgeNetworkReachable() async {
  try {
    final result = await InternetAddress.lookup('speech.platform.bing.com');
    return result.isNotEmpty;
  } catch (_) {
    return false;
  }
}
