import 'dart:convert';

import '../api/ApiUrls.dart';
import '../utils/ApiClient.dart';

class FriendLinkRecord {
  final String name;
  final String description;
  final String url;
  final String iconType;
  final String iconColor;

  const FriendLinkRecord({
    required this.name,
    required this.description,
    required this.url,
    required this.iconType,
    required this.iconColor,
  });

  factory FriendLinkRecord.fromJson(Map<String, dynamic> json) {
    return FriendLinkRecord(
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      url: (json['url'] as String? ?? '').trim(),
      iconType: (json['icon_type'] as String? ?? 'web').trim(),
      iconColor: (json['icon_color'] as String? ?? '#5C6BC0').trim(),
    );
  }
}

class FriendLinksService {
  const FriendLinksService();

  Future<List<FriendLinkRecord>> fetch() async {
    final response = await ApiClient.get(Uri.parse(ApiUrls.FriendLinksUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final raw = decoded is Map<String, dynamic> ? decoded['links'] : decoded;
    if (raw is! List) throw const FormatException('友链数据格式错误');
    return [
      for (final item in raw)
        if (item is Map<String, dynamic>) FriendLinkRecord.fromJson(item),
    ].where((item) => item.name.isNotEmpty && item.url.isNotEmpty).toList();
  }
}
