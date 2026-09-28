import 'package:flutter_test/flutter_test.dart';
import 'package:moyue_reader/services/tts/edge_tts_engine.dart';

void main() {
  final engine = EdgeTtsEngine();

  group('EdgeTtsEngine 协议', () {
    test('Sec-MS-GEC 是 64 位大写十六进制', () {
      final gec = engine.generateSecMsGec();
      expect(gec.length, 64);
      expect(RegExp(r'^[0-9A-F]{64}$').hasMatch(gec), isTrue);
    });

    test('WSS 地址包含全部必需查询参数', () {
      final uri = engine.buildUri();
      expect(uri.scheme, 'wss');
      expect(uri.host, 'speech.platform.bing.com');
      expect(uri.path,
          '/consumer/speech/synthesize/readaloud/edge/v1');
      expect(uri.queryParameters['TrustedClientToken'], isNotEmpty);
      expect(uri.queryParameters['Sec-MS-GEC'], isNotEmpty);
      expect(uri.queryParameters['Sec-MS-GEC-Version'], isNotEmpty);
      expect(uri.queryParameters['ConnectionId'], isNotEmpty);
    });

    test('内置中文音色列表可用', () async {
      final voices = await engine.voices();
      expect(voices, isNotEmpty);
      expect(voices.any((v) => v.shortName == 'zh-CN-XiaoxiaoNeural'), isTrue);
    });
  });
}
