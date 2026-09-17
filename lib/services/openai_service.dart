import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/leadership.dart';

class AssistantException implements Exception {
  final String message;
  const AssistantException(this.message);
  @override
  String toString() => message;
}

class OpenAIService {
  static const storage = FlutterSecureStorage();
  final http.Client client;
  OpenAIService({http.Client? client}) : client = client ?? http.Client();
  static Future<void> configure(String url, String token) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const AssistantException('أدخل رابط خادم HTTPS صالحًا');
    }
    if (token.trim().length < 20) {
      throw const AssistantException('رمز اتصال الخادم غير مكتمل');
    }
    await storage.write(
      key: 'assistant_url',
      value: url.trim().replaceAll(RegExp(r'/+$'), ''),
    );
    await storage.write(key: 'assistant_token', value: token.trim());
  }

  Future<(Uri, Map<String, String>)> _config(String path) async {
    final url =
        await storage.read(key: 'assistant_url') ??
        const String.fromEnvironment('ASSISTANT_URL');
    final token =
        await storage.read(key: 'assistant_token') ??
        const String.fromEnvironment('ASSISTANT_TOKEN');
    final uri = Uri.tryParse('$url/$path');
    if (url.isEmpty || token.isEmpty || uri?.scheme != 'https') {
      throw const AssistantException(
        'اضبط اتصال خادم المساعد من زر الإعدادات أعلى الصفحة',
      );
    }
    return (uri!, {'Authorization': 'Bearer $token'});
  }

  void _check(http.Response response) {
    if (response.statusCode == 200) return;
    String? code;
    try {
      code = (jsonDecode(response.body) as Map)['error'] as String?;
    } catch (_) {}
    throw AssistantException(switch (code) {
      'openai_key_invalid' => 'مفتاح OpenAI غير صالح. حدّثه في الخادم.',
      'model_unavailable' ||
      'model_access_denied' => 'الموديل المطلوب غير متاح لهذا الحساب.',
      'openai_quota_or_rate_limit' =>
        'رصيد OpenAI أو حد الطلبات غير متاح حاليًا.',
      'unauthorized' => 'رمز اتصال الخادم غير صحيح.',
      _ => 'تعذر الاتصال بخدمة الذكاء الاصطناعي. حاول مجددًا.',
    });
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final (uri, headers) = await _config(path);
    final r = await client
        .post(
          uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 55));
    _check(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<String> transcribe(Uint8List bytes) async {
    final (uri, headers) = await _config('transcribe');
    final req = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..files.add(
        http.MultipartFile.fromBytes('audio', bytes, filename: 'command.m4a'),
      );
    final r = await http.Response.fromStream(
      await client.send(req).timeout(const Duration(seconds: 55)),
    );
    _check(r);
    return (jsonDecode(utf8.decode(r.bodyBytes))['transcript'] as String)
        .trim();
  }

  Future<VoiceDecision> intent(String text) async =>
      VoiceDecision.fromJson(await post('intent', {'transcript': text}));
  Future<String> analyze(Uint8List frame) async =>
      (await post('analyze', {
            'explicit_capture': true,
            'image': base64Encode(frame),
          }))['reply']
          as String;
  Future<String> brief(Map<String, dynamic> facts) async =>
      (await post('brief', {'facts': facts}))['reply'] as String;
  Future<Uint8List> speech(String text) async {
    final (uri, headers) = await _config('speech');
    final r = await client
        .post(
          uri,
          headers: {...headers, 'Content-Type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 55));
    _check(r);
    return r.bodyBytes;
  }

  void dispose() => client.close();
}
