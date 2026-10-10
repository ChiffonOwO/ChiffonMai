import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/api/ApiUrls.dart';
import 'package:my_first_flutter_app/utils/ApiClient.dart';

/// 收藏品说明翻译服务。
///
/// 腾讯云 TMT 已停止使用，现由自家服务端代理百度翻译大模型文本翻译 API。
/// 百度凭据只保存在服务端，客户端不再携带 App ID、API Key 或 Secret Key。
class TranslateService {
  static final Map<String, String> _memoryCache = <String, String>{};
  static final Map<String, Future<String?>> _pending =
      <String, Future<String?>>{};

  static final RegExp _japaneseRegex =
      RegExp(r'[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uff66-\uff9f]');
  static final RegExp _englishRegex = RegExp(r'[a-zA-Z]');

  static String detectLanguage(String text) {
    if (_japaneseRegex.hasMatch(text)) return 'ja';
    if (_englishRegex.hasMatch(text)) return 'en';
    return 'auto';
  }

  static List<Map<String, String>> splitMixedLanguageText(String text) {
    final segments = <Map<String, String>>[];
    var currentSegment = '';
    var currentLang = '';
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      final charLang = _japaneseRegex.hasMatch(char)
          ? 'ja'
          : (_englishRegex.hasMatch(char) ? 'en' : 'other');
      if (currentLang.isEmpty) {
        currentLang = charLang;
        currentSegment = char;
      } else if (currentLang == charLang) {
        currentSegment += char;
      } else {
        segments.add({'text': currentSegment, 'lang': currentLang});
        currentLang = charLang;
        currentSegment = char;
      }
    }
    if (currentSegment.isNotEmpty) {
      segments.add({'text': currentSegment, 'lang': currentLang});
    }
    return segments;
  }

  static Future<String?> translateMixedLanguage(String text,
      {String to = 'zh'}) async {
    try {
      final translatedSegments = <String>[];
      for (final segment in splitMixedLanguageText(text)) {
        final lang = segment['lang'];
        final source = segment['text']!;
        if (lang == 'ja' || lang == 'en') {
          translatedSegments
              .add(await translate(source, from: lang!, to: to) ?? source);
        } else {
          translatedSegments.add(source);
        }
      }
      return translatedSegments.join();
    } catch (e) {
      debugPrint('混合语言翻译失败: $e');
      return null;
    }
  }

  static Future<String?> enToZh(String text) =>
      translate(text, from: 'en', to: 'zh');

  static Future<String?> jaToZh(String text) =>
      translate(text, from: 'ja', to: 'zh');

  static Future<String?> translateMixed(String text) =>
      translateMixedLanguage(text);

  static Future<String?> translate(String text,
      {String from = 'auto', String to = 'zh'}) {
    final source = text.trim();
    if (source.isEmpty) return Future<String?>.value(source);
    final key = '$from|$to|$source';
    final cached = _memoryCache[key];
    if (cached != null) return Future<String?>.value(cached);
    final existing = _pending[key];
    if (existing != null) return existing;
    final future = _requestBaidu(source, from: from, to: to);
    _pending[key] = future;
    return future.whenComplete(() => _pending.remove(key));
  }

  static Future<String?> _requestBaidu(String text,
      {required String from, required String to}) async {
    try {
      final response = await ApiClient.post(
        Uri.parse(ApiUrls.TranslationUrl),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'q': text, 'from': from, 'to': to}),
        timeout: const Duration(seconds: 35),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('服务端翻译响应异常: ${response.statusCode}');
        return null;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map || data['translation'] is! String) {
        debugPrint('服务端翻译失败: ${data is Map ? data['error'] : '未知错误'}');
        return null;
      }
      final result = data['translation'] as String;
      if (result.isEmpty) return null;
      _memoryCache['$from|$to|$text'] = result;
      return result;
    } catch (e) {
      debugPrint('百度翻译请求失败: $e');
      return null;
    }
  }
}
