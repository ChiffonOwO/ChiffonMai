import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 调试开关
const bool _kDebugBili = true;
void _log(String msg) {
  if (_kDebugBili) debugPrint('[BiliSearch] $msg');
}

/// B站搜索结果
class BiliSearchResult {
  final int playCount;
  final String bvid;
  final String title;

  const BiliSearchResult({
    required this.playCount,
    required this.bvid,
    required this.title,
  });
}

/// B站视频信息（通过 BV 号获取）
class BiliVideoInfo {
  final String bvid;
  final String title;
  final int playCount;
  final String author;
  final String duration;

  const BiliVideoInfo({
    required this.bvid,
    required this.title,
    required this.playCount,
    required this.author,
    required this.duration,
  });
}

/// B站视频搜索服务（单例）
///
/// 用于搜索"谱面确认 + 歌曲名 + 难度"的视频播放量。
/// 内部处理 WBI 签名、Session 持久化、风控重试。
class BiliSearchService {
  static final BiliSearchService _instance = BiliSearchService._internal();
  factory BiliSearchService() => _instance;
  BiliSearchService._internal() {
    _log('BiliSearchService 单例初始化');
  }

  // ---- 内部状态 ----
  http.Client? _client;
  String _buvid3 = '';
  String _imgKey = '';
  String _subKey = '';
  int _wbiExpireAt = 0; // 秒级时间戳

  // ---- WBI 固定重排表 ----
  static const _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35,
    27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13,
    37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4,
    22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
  ];

  // ---- 难度标签 ----
  static const _diffLabels = ['Basic', 'Advanced', 'Expert', 'Master', 'Re:Master'];

  // ===================================================================
  // 对外 API
  // ===================================================================

  /// 取消进行中的请求
  bool _cancelled = false;
  void cancel() => _cancelled = true;

  /// 搜索结果（包含播放量和最佳匹配 BV 号）
  BiliSearchResult? _lastSearchResult;

  /// 搜索"谱面确认 + 歌曲名 + 难度"视频的最高播放量
  ///
  /// [songTitle] 歌曲名
  /// [diffIndex] 难度索引 (0=Basic, 1=Advanced, 2=Expert, 3=Master, 4=Re:Master)
  ///
  /// 返回播放量（int），无结果或出错返回 null。
  /// 成功搜索后，可通过 [_lastSearchResult] 获取最佳匹配的 BV 号。
  Future<int?> fetchMaxPlayCount(String songTitle, int diffIndex) async {
    if (diffIndex < 0 || diffIndex >= _diffLabels.length) return null;
    final diffLabel = _diffLabels[diffIndex];

    // 多种关键词组合，按优先级依次尝试
    final keywords = [
      '谱面确认 $songTitle $diffLabel',
      '谱面确认 $songTitle',
      '$songTitle $diffLabel',
      '$songTitle 手元 $diffLabel',
      songTitle,
    ];

    _log('══════════════════════════════');
    _log('搜索: $songTitle / $diffLabel');
    _cancelled = false;

    try {
      await _initSession();
      if (_cancelled) return null;

      for (final keyword in keywords) {
        if (_cancelled) return null;

        // 每种关键词至多重试2次
        for (int attempt = 0; attempt < 2 && !_cancelled; attempt++) {
          if (attempt > 0) {
            _log('重试: "$keyword"');
            await Future.delayed(Duration(milliseconds: 500 + attempt * 300));
          }

          final videos = await _search(keyword);
          if (_cancelled) return null;

          if (videos.isEmpty) continue;

          // 过滤：包含歌曲名 + 难度标签
          final filtered = <Map<String, dynamic>>[];
          for (final v in videos) {
            final title = (v['title'] as String?) ?? '';
            final author = (v['author'] as String?) ?? '';
            final combined = '$title $author';
            if (combined.contains(songTitle) && _containsDiffLabel(combined, diffLabel)) {
              filtered.add(v);
            }
          }

          if (filtered.isEmpty) continue;

          // 取最大播放量
          int maxPlay = 0;
          String bestBvid = '';
          String bestTitle = '';
          for (final v in filtered) {
            final play = (v['play'] as int?) ?? 0;
            if (play > maxPlay) {
              maxPlay = play;
              bestBvid = (v['bvid'] as String?) ?? '';
              bestTitle = (v['title'] as String?) ?? '';
            }
          }

          // 保存搜索结果，方便外部获取最佳匹配 BV 号
          _lastSearchResult = BiliSearchResult(
            playCount: maxPlay,
            bvid: bestBvid,
            title: bestTitle,
          );

          _log('命中: "$keyword" → ${filtered.length}个匹配, 最高播放量: $maxPlay, BV: $bestBvid');
          return maxPlay > 0 ? maxPlay : null;
        }

        _log('"$keyword" 无匹配');
      }

      _log('所有关键词均无匹配视频');
      return null;
    } catch (e, stack) {
      _log('搜索异常: $e');
      _log('Stack: $stack');
      return null;
    }
  }

  // ===================================================================
  // Session 初始化
  // ===================================================================

  Future<void> _initSession() async {
    if (_client != null && _buvid3.isNotEmpty && !_wbiExpired) return;

    _log('初始化 Session...');
    _client?.close();
    _client = http.Client();

    // Step 1: 访问首页拿 buvid3
    try {
      final resp = await _client!.get(
        Uri.parse('https://www.bilibili.com'),
        headers: _baseHeaders(isHtml: true),
      );
      final setCookie = resp.headers['set-cookie'] ?? '';
      final match = RegExp(r'buvid3=([^;]+)').firstMatch(setCookie);
      if (match != null) {
        _buvid3 = 'buvid3=${match.group(1)}';
        _log('获取 buvid3: ${_buvid3}');
      }
    } catch (e) {
      _log('首页请求异常: $e');
    }

    // 没拿到就随机生成
    if (_buvid3.isEmpty) {
      _buvid3 = 'buvid3=${_randomUUID().toUpperCase()}infoc';
      _log('生成随机 buvid3: $_buvid3');
    }

    // Step 2: 获取 WBI 密钥
    await _fetchWbiKeys();
  }

  bool get _wbiExpired =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 > _wbiExpireAt;

  Future<void> _fetchWbiKeys() async {
    _log('获取 WBI 密钥...');
    try {
      final resp = await _client!.get(
        Uri.parse('https://api.bilibili.com/x/web-interface/nav'),
        headers: _apiHeaders(),
      );
      _log('/nav HTTP ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final wbi = (data['data'] as Map<String, dynamic>?)?.tryGet<Map<String, dynamic>>('wbi_img');
        if (wbi != null) {
          _imgKey = (wbi['img_url'] as String).split('/').last.split('.').first;
          _subKey = (wbi['sub_url'] as String).split('/').last.split('.').first;
          _wbiExpireAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 4 * 3600;
          _log('WBI 密钥已更新: imgKey=${_imgKey.substring(0, 8)}...');
        }
      }
    } catch (e) {
      _log('获取 WBI 密钥异常: $e');
    }
  }

  // ===================================================================
  // 搜索
  // ===================================================================

  /// 搜索视频，返回原始结果列表
  Future<List<Map<String, dynamic>>> _search(String keyword) async {
    if (_imgKey.isEmpty || _subKey.isEmpty) {
      await _fetchWbiKeys();
      if (_imgKey.isEmpty) return [];
    }

    final params = _signWbi({
      'search_type': 'video',
      'keyword': keyword,
      'page': '1',
    });

    final uri = Uri.parse(
      'https://api.bilibili.com/x/web-interface/wbi/search/type',
    ).replace(queryParameters: params);

    _log('搜索请求: keyword=$keyword');

    for (int attempt = 0; attempt < 3 && !_cancelled; attempt++) {
      try {
        final resp = await _client!.get(uri, headers: _apiHeaders());
        _log('搜索响应: HTTP ${resp.statusCode}');

        if (resp.statusCode != 200) continue;

        final body = resp.body;
        if (body.isEmpty) {
          _log('空响应体');
          continue;
        }

        final data = json.decode(body) as Map<String, dynamic>;
        final code = data.tryGet<int>('code') ?? -1;

        if (code == 0) {
          final result = (data['data'] as Map<String, dynamic>?)?.tryGet<List>('result') ?? [];
          return result
              .whereType<Map<String, dynamic>>()
              .where((r) => r.tryGet<String>('type') == 'video')
              .map((r) => {
                    'title': (r.tryGet<String>('title') ?? '').replaceAll(RegExp(r'<[^>]+>'), ''),
                    'bvid': r.tryGet<String>('bvid') ?? '',
                    'play': r.tryGet<int>('play') ?? 0,
                    'author': r.tryGet<String>('author') ?? '',
                    'duration': r.tryGet<String>('duration') ?? '',
                  })
              .toList();
        }

        // 风控，重试
        if (code == -412 || code == -799 || code == -352) {
          _log('被风控 (code=$code)，重试...');
          await Future.delayed(Duration(seconds: (attempt + 1) * 2));
          if (code == -412) {
            // 重置 Session
            _client?.close();
            _client = null;
            _buvid3 = '';
            await _initSession();
          }
          continue;
        }

        _log('API 错误: code=$code, msg=${data.tryGet<String>('message')}');
      } catch (e) {
        _log('搜索请求异常: $e');
        if (attempt < 2) await Future.delayed(const Duration(seconds: 2));
      }
    }

    return [];
  }

  // ===================================================================
  // WBI 签名
  // ===================================================================

  Map<String, String> _signWbi(Map<String, String> params) {
    final mixinKey = _getMixinKey();
    params['wts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sorted = Map.fromEntries(params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    final queryString = Uri(queryParameters: sorted).query;
    final sign = md5.convert(utf8.encode('$queryString$mixinKey')).toString();
    sorted['w_rid'] = sign;
    return sorted;
  }

  String _getMixinKey() {
    final raw = '$_imgKey$_subKey';
    final chars = _mixinKeyEncTab.where((i) => i < raw.length).map((i) => raw[i]);
    return chars.take(32).join();
  }

  // ===================================================================
  // 辅助方法
  // ===================================================================

  Map<String, String> _baseHeaders({bool isHtml = false}) => {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': isHtml
            ? 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
            : 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
      };

  Map<String, String> _apiHeaders() => {
        ..._baseHeaders(),
        'Referer': 'https://www.bilibili.com',
        if (_buvid3.isNotEmpty) 'Cookie': _buvid3,
      };

  /// 检查字符串中是否包含难度标签
  bool _containsDiffLabel(String text, String label) {
    // 中文映射
    const cnMap = {
      'Basic': ['Basic', 'basic', '绿谱', '绿', 'BASIC'],
      'Advanced': ['Advanced', 'advanced', '黄谱', '黄', 'ADVANCED'],
      'Expert': ['Expert', 'expert', '红谱', '红', 'EXPERT'],
      'Master': ['Master', 'master', '紫谱', '紫', 'MASTER'],
      'Re:Master': ['Re:Master', 'ReMaster', 'remaster', 're:master', '白谱', '白', 'REM', 'Re:MASTER'],
    };
    final keywords = cnMap[label] ?? [label];
    return keywords.any((k) => text.contains(k));
  }

  static String _randomUUID() {
    final r = Random();
    return '${_hex(r, 8)}-${_hex(r, 4)}-${_hex(r, 4)}-${_hex(r, 4)}-${_hex(r, 12)}';
  }

  static String _hex(Random r, int len) {
    const chars = '0123456789ABCDEF';
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // ===================================================================
  // 获取最近一次搜索的最佳匹配 BV 号
  // ===================================================================

  /// 获取最近一次 [fetchMaxPlayCount] 搜索的最佳匹配结果
  BiliSearchResult? get lastSearchResult => _lastSearchResult;

  // ===================================================================
  // BV 号视频信息查询与校验
  // ===================================================================

  /// 根据 BV 号获取视频信息
  ///
  /// [bvid] 视频 BV 号（如 "BV1xx411c7mD"）
  ///
  /// 返回 [BiliVideoInfo]，失败返回 null
  Future<BiliVideoInfo?> fetchVideoByBv(String bvid) async {
    _log('查询 BV 视频信息: $bvid');
    _cancelled = false;

    try {
      await _initSession();
      if (_cancelled) return null;

      // 调用 B站视频信息 API
      final uri = Uri.parse(
        'https://api.bilibili.com/x/web-interface/view?bvid=$bvid',
      );

      for (int attempt = 0; attempt < 3 && !_cancelled; attempt++) {
        try {
          final resp = await _client!.get(uri, headers: _apiHeaders());
          _log('BV 查询响应: HTTP ${resp.statusCode}');

          if (resp.statusCode != 200) continue;

          final data = json.decode(resp.body) as Map<String, dynamic>;
          final code = data.tryGet<int>('code') ?? -1;

          if (code == 0) {
            final videoData = data['data'] as Map<String, dynamic>?;
            if (videoData == null) return null;

            final info = BiliVideoInfo(
              bvid: bvid,
              title: (videoData.tryGet<String>('title') ?? '').replaceAll(RegExp(r'<[^>]+>'), ''),
              playCount: videoData.tryGet<Map<String, dynamic>>('stat')?.tryGet<int>('view') ?? 0,
              author: videoData.tryGet<Map<String, dynamic>>('owner')?.tryGet<String>('name') ?? '',
              duration: _formatDuration(videoData.tryGet<int>('duration') ?? 0),
            );

            _log('BV 查询成功: 标题="${info.title}", 播放=${info.playCount}, UP=${info.author}');
            return info;
          }

          // 视频不存在或已删除
          if (code == -404 || code == 62002 || code == 62004) {
            _log('BV 视频不存在: code=$code');
            return null;
          }

          if (code == -412) {
            _log('被风控，重试...');
            await Future.delayed(Duration(seconds: (attempt + 1) * 2));
            continue;
          }

          _log('API 错误: code=$code, msg=${data.tryGet<String>('message')}');
        } catch (e) {
          _log('BV 查询请求异常: $e');
          if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
        }
      }

      return null;
    } catch (e) {
      _log('BV 查询异常: $e');
      return null;
    }
  }

  /// 校验 BV 号对应的视频标题是否包含目标歌曲标题
  ///
  /// [bvid] 用户提供的 BV 号
  /// [songTitle] 歌曲标题（用于匹配校验）
  ///
  /// 返回校验结果：
  /// - `null` 表示查询失败
  /// - `BvValidationResult` 包含校验是否通过及视频信息
  Future<BvValidationResult?> validateBvForSong(
    String bvid,
    String songTitle,
  ) async {
    _log('校验 BV: $bvid 是否属于歌曲 "$songTitle"');

    final videoInfo = await fetchVideoByBv(bvid);
    if (videoInfo == null) {
      _log('校验失败: 无法获取视频信息');
      return null;
    }

    // 检查视频标题是否包含歌曲标题（忽略大小写）
    final videoTitle = videoInfo.title.toLowerCase();
    final searchTitle = songTitle.toLowerCase();
    final containsTitle = videoTitle.contains(searchTitle);

    _log('校验结果: ${containsTitle ? "通过" : "失败"} - 视频标题="${videoInfo.title}", 歌曲="$songTitle"');

    return BvValidationResult(
      passed: containsTitle,
      videoInfo: videoInfo,
      songTitle: songTitle,
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// BV 号校验结果
class BvValidationResult {
  /// 是否通过校验（视频标题包含歌曲标题）
  final bool passed;

  /// 视频信息
  final BiliVideoInfo videoInfo;

  /// 用于校验的歌曲标题
  final String songTitle;

  const BvValidationResult({
    required this.passed,
    required this.videoInfo,
    required this.songTitle,
  });
}

// ===================================================================
// Map 安全取值扩展
// ===================================================================

extension SafeMapAccess on Map<String, dynamic> {
  T? tryGet<T>(String key) {
    final val = this[key];
    if (val is T) return val;
    if (T == int && val is num) return val.toInt() as T;
    if (T == double && val is num) return val.toDouble() as T;
    if (T == String && val != null) return val.toString() as T;
    if (T == bool && val != null) {
      if (val is bool) return val as T;
      if (val is String) {
        final lower = val.toLowerCase();
        if (lower == 'true') return true as T;
        if (lower == 'false') return false as T;
      }
    }
    return null;
  }
}
