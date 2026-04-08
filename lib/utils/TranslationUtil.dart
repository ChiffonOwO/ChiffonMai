import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:my_first_flutter_app/api/DeveloperToken.dart';
import 'package:intl/intl.dart';

class TranslateService {
  static const String secretId = DeveloperToken.TencentSecretId;
  static const String secretKey = DeveloperToken.TencentSecretKey;
  static const String service = "tmt";
  static const String region = "ap-beijing";
  static const String host = "tmt.tencentcloudapi.com";
  static const String version = "2018-03-21";
  static const String algorithm = "TC3-HMAC-SHA256";

  // 英译中
  static Future<String?> enToZh(String text) async {
    return await translate(text, from: "en", to: "zh");
  }

  // 日译中
  static Future<String?> jaToZh(String text) async {
    return await translate(text, from: "ja", to: "zh");
  }

  // 核心翻译
  static Future<String?> translate(String text, {String from = "auto", String to = "zh"}) async {
    try {
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000).toInt();
      final uri = Uri.https(host, "/");

      // 确保语言代码正确
      print("翻译请求: 文本='$text', 源语言='$from', 目标语言='$to'");
      
      final body = jsonEncode({
        "SourceText": text,
        "Source": from,
        "Target": to,
        "ProjectId": 0,
      });
      print("请求体: $body");

      final headers = {
        "Content-Type": "application/json; charset=utf-8",
        "X-TC-Action": "TextTranslate",
        "X-TC-Version": version,
        "X-TC-Region": region,
        "X-TC-Timestamp": timestamp.toString(),
        "X-TC-Token": "",
        "Host": host,
        "Authorization": _buildAuth(timestamp, body),
      };

      final res = await http.post(uri, headers: headers, body: body);
      
      // 打印响应信息以便调试
      print("响应状态码: ${res.statusCode}");
      print("响应头部: ${res.headers}");
      print("响应体: ${res.body}");
      
      // 尝试不同的解码方式处理乱码
      String responseBody = res.body;
      try {
        // 尝试UTF-8解码
        responseBody = utf8.decode(res.bodyBytes);
        print("UTF-8解码后: $responseBody");
      } catch (e) {
        print("UTF-8解码失败: $e");
      }
      
      final data = jsonDecode(responseBody);

      if (data["Response"]?.containsKey("Error") == true) {
        print("腾讯云API错误: ${data["Response"]["Error"]}");
        return null;
      }

      final targetText = data["Response"]["TargetText"];
      print("翻译结果: $targetText");
      
      // 尝试对结果进行二次解码
      try {
        final decodedText = utf8.decode(targetText.runes.toList());
        print("二次解码后: $decodedText");
        return decodedText;
      } catch (e) {
        print("二次解码失败: $e");
        return targetText;
      }
    } catch (e) {
      print("翻译失败: $e");
      return null;
    }
  }

  // ✅ 严格按照腾讯云API签名v3官方文档实现
  static String _buildAuth(int timestamp, String payload) {
    // 1. 时间与日期（官方格式）
    final utcTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
    final date = DateFormat('yyyy-MM-dd').format(utcTime);

    // 2. 请求参数
    final httpRequestMethod = "POST";
    final canonicalUri = "/";
    final canonicalQuerystring = "";
    final ct = "application/json; charset=utf-8";
    final action = "TextTranslate";

    // 3. 规范请求头
    final canonicalHeaders = "content-type:$ct\nhost:$host\nx-tc-action:${action.toLowerCase()}\n";
    final signedHeaders = "content-type;host;x-tc-action";

    // 4. payload 哈希
    final hashedRequestPayload = sha256.convert(utf8.encode(payload)).toString();

    // 5. 拼接规范请求串
    final canonicalRequest = '''
$httpRequestMethod
$canonicalUri
$canonicalQuerystring
$canonicalHeaders
$signedHeaders
$hashedRequestPayload''';

    // 6. 待签名字符串
    final credentialScope = "$date/$service/tc3_request";
    final hashedCanonicalRequest = sha256.convert(utf8.encode(canonicalRequest)).toString();
    final stringToSign = '''
$algorithm
$timestamp
$credentialScope
$hashedCanonicalRequest''';

    // 7. 计算签名（完全官方逻辑）
    List<int> sign(List<int> key, String msg) {
      final hmacSha256 = Hmac(sha256, key);
      return hmacSha256.convert(utf8.encode(msg)).bytes;
    }

    final secretDate = sign(utf8.encode('TC3$secretKey'), date);
    final secretService = sign(secretDate, service);
    final secretSigning = sign(secretService, 'tc3_request');
    final signature = Hmac(sha256, secretSigning).convert(utf8.encode(stringToSign)).toString();

    // 8. 生成 Authorization
    return "$algorithm Credential=$secretId/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature";
  }
}