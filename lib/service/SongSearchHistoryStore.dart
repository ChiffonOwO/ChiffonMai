import 'package:shared_preferences/shared_preferences.dart';

/// 只记录真正执行过的关键词，最新搜索靠前，重复关键词移动到最前。
class SongSearchHistoryStore {
  static const cacheKey = 'song_search_history_v1';
  static const maxEntries = 20;
  static Future<void> _writes = Future<void>.value();

  Future<List<String>> load() async {
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    return _normalize(prefs.getStringList(cacheKey) ?? const []);
  }

  Future<List<String>> remember(String query) => _update((items) {
        final keyword = query.trim();
        if (keyword.isEmpty) return items;
        return [keyword, ...items.where((item) =>
            item.toLowerCase() != keyword.toLowerCase())];
      });

  Future<List<String>> remove(String query) => _update((items) =>
      items.where((item) => item != query).toList());

  Future<List<String>> clear() => _update((_) => []);

  Future<List<String>> _update(
      List<String> Function(List<String>) change) {
    final result = _writes.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final items = _normalize(change(
          _normalize(prefs.getStringList(cacheKey) ?? const [])));
      if (!await prefs.setStringList(cacheKey, items)) {
        throw StateError('搜索历史保存失败');
      }
      return items;
    });
    // 写入串行执行；一次失败不会阻断之后的删除、清空或搜索。
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  static List<String> _normalize(List<String> items) {
    final seen = <String>{};
    return items.map((item) => item.trim()).where((item) =>
        item.isNotEmpty && seen.add(item.toLowerCase()))
        .take(maxEntries).toList();
  }
}
