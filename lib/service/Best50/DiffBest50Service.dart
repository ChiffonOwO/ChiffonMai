import 'package:flutter/foundation.dart';

import '../../manager/UserPlayDataManager.dart';
import '../../manager/DiffMusicDataManager.dart';
import '../../manager/UserBest50Manager.dart';
import '../../manager/MaimaiMusicDataManager.dart';

class DiffBest50Service {
  // 单例模式
  static final DiffBest50Service _instance = DiffBest50Service._internal();
  factory DiffBest50Service() => _instance;
  DiffBest50Service._internal();

  // 舞萌DX 完成度-评级-乘数对照表
  final List<Map<String, dynamic>> maimaiRatingMultiplier = [
    {"completion": 100.5, "rating": "SSS+", "multiplier": 0.224},
    {"completion": 100.4999, "rating": "SSS", "multiplier": 0.222},
    {"completion": 100.0, "rating": "SSS", "multiplier": 0.216},
    {"completion": 99.9999, "rating": "SS+", "multiplier": 0.214},
    {"completion": 99.5, "rating": "SS+", "multiplier": 0.211},
    {"completion": 99.0, "rating": "SS", "multiplier": 0.208},
    {"completion": 98.9999, "rating": "S+", "multiplier": 0.206},
    {"completion": 98.0, "rating": "S+", "multiplier": 0.203},
    {"completion": 97.0, "rating": "S", "multiplier": 0.2},
    {"completion": 96.9999, "rating": "AAA", "multiplier": 0.176},
    {"completion": 94.0, "rating": "AAA", "multiplier": 0.168},
    {"completion": 90.0, "rating": "AA", "multiplier": 0.152},
    {"completion": 80.0, "rating": "A", "multiplier": 0.136},
    {"completion": 79.9999, "rating": "BBB", "multiplier": 0.128},
    {"completion": 75.0, "rating": "BBB", "multiplier": 0.120},
    {"completion": 70.0, "rating": "BB", "multiplier": 0.112},
    {"completion": 60.0, "rating": "B", "multiplier": 0.096},
    {"completion": 50.0, "rating": "C", "multiplier": 0.08},
    {"completion": 40.0, "rating": "D", "multiplier": 0.064},
    {"completion": 30.0, "rating": "D", "multiplier": 0.048},
    {"completion": 20.0, "rating": "D", "multiplier": 0.032},
    {"completion": 10.0, "rating": "D", "multiplier": 0.016},
  ];

  // 加载歌曲难度数据
  Future<Map<String, dynamic>> loadSongDiffData() async {
    try {
      // 从 DiffMusicDataManager 获取缓存的拟合难度数据
      final diffMusicDataManager = DiffMusicDataManager();
      if (await diffMusicDataManager.hasCachedData()) {
        final diffSong = await diffMusicDataManager.getCachedDiffData();
        if (diffSong != null) {
          // 构建歌曲难度数据结构
          Map<String, dynamic> diffData = {'charts': {}};
          diffSong.charts.forEach((songId, diffDataList) {
            List<Map<String, dynamic>> songCharts = [];
            for (var diffDataItem in diffDataList) {
              songCharts.add({
                'fit_diff': diffDataItem.fitDiff.toDouble()
              });
            }
            diffData['charts'][songId] = songCharts;
          });
          return diffData;
        }
      }
      return {};
    } catch (e) {
      debugPrint('加载歌曲难度数据失败: $e');
      return {};
    }
  }

  // 获取用户游玩记录
  Future<Map<String, dynamic>?> getUserPlayData() async {
    try {
      final userPlayDataManager = UserPlayDataManager();
      return await userPlayDataManager.getCachedUserPlayData();
    } catch (e) {
      debugPrint('获取用户游玩数据失败: $e');
      return null;
    }
  }

  // 计算单曲Rating
  int calculateSingleRating(double difficulty, double completion) {
    // 特别处理：如果达成率大于100.5，则按100.5计算
    double adjustedCompletion = completion > 100.5 ? 100.5 : completion;
    double calculationCompletion = completion > 100.5 ? 100.5 : completion;

    // 查找对应的评级和乘数
    Map<String, dynamic>? selectedRating;
    
    // 遍历表格查找正确的区间
    for (var item in maimaiRatingMultiplier) {
      if (adjustedCompletion >= item['completion']) {
        selectedRating = item;
        break;
      }
    }
    
    // 如果没有找到（不应该发生），使用默认值
    selectedRating ??= {"rating": "D", "multiplier": 0.016};

    double multiplier = selectedRating['multiplier'];

    // 计算单曲Rating
    double singleRating = difficulty * multiplier * calculationCompletion;
    return singleRating.floor(); // 取整数部分（向下取整）
  }

  // 计算DiffBest50数据（模式A：使用拟合定数重新计算Rating并取前50）
  Future<Map<String, dynamic>> calculateDiffBest50() async {
    return await _calculateDiffBest50ModeA();
  }

  // 模式A：使用拟合定数重新计算所有歌曲的Rating，按新Rating排序取前50
  Future<Map<String, dynamic>> _calculateDiffBest50ModeA() async {
    try {
      // 加载歌曲难度数据
      final songDiffData = await loadSongDiffData();
      if (songDiffData.isEmpty) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'best50Diff': 0};
      }

      // 获取用户游玩记录
      final userData = await getUserPlayData();
      if (userData == null || userData['records'] == null) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'best50Diff': 0};
      }

      final records = userData['records'];
      final chartsData = songDiffData['charts'];

      // 存储计算结果
      List<Map<String, dynamic>> diffBest50 = [];

      // 遍历用户游玩记录
      for (var record in records) {
        int songId = record['song_id'];
        int levelIndex = record['level_index'];
        double achievements = double.parse(record['achievements'].toString());

        // 查找对应的歌曲难度数据
        if (chartsData.containsKey(songId.toString())) {
          final songCharts = chartsData[songId.toString()];
          if (levelIndex < songCharts.length) {
            final chartData = songCharts[levelIndex];
            double fitDiff = chartData['fit_diff'] ?? 0.0;

            // 计算DiffRating
            int diffRating = calculateSingleRating(fitDiff, achievements);

            // 添加到结果列表
            diffBest50.add({
              'song_id': songId,
              'level_index': levelIndex,
              'title': record['title'],
              'type': record['type'],
              'ds': record['ds'],
              'achievements': achievements,
              'dxScore': record['dxScore'],
              'fc': record['fc'],
              'fs': record['fs'],
              'rate': record['rate'],
              'ra': record['ra'],
              'diffRating': diffRating,
              'fit_diff': fitDiff,
            });
          }
        }
      }

      // 按DiffRating降序排序
      diffBest50.sort((a, b) => b['diffRating'].compareTo(a['diffRating']));

      // 取前50条
      if (diffBest50.length > 50) {
        diffBest50 = diffBest50.sublist(0, 50);
      }

      // 计算DiffRating总和
      int diffRatingSum = diffBest50.fold(0, (sum, item) => sum + (item['diffRating'] as int));

      // 计算与Best50的差值
      int best50Sum = userData['rating'] ?? 0;
      int best50Diff = diffRatingSum - best50Sum;

      return {
        'diffRatingSum': diffRatingSum,
        'diffBest50': diffBest50,
        'best50Diff': best50Diff,
      };
    } catch (e) {
      debugPrint('计算DiffBest50数据失败: $e');
      return {'diffRatingSum': 0, 'diffBest50': [], 'best50Diff': 0};
    }
  }

  // 模式B：从Best50数据获取排名，将定数替换为拟合定数并重新计算Rating
  Future<Map<String, dynamic>> calculateDiffBest50ModeB() async {
    try {
      // 加载歌曲难度数据
      final songDiffData = await loadSongDiffData();
      if (songDiffData.isEmpty) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
      }

      // 获取用户Best50数据（已排序）
      final best50Manager = UserBest50Manager();
      final best50Data = await best50Manager.getCachedBest50Data();
      if (best50Data == null) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
      }

      // 获取用户游玩记录（用于获取详细数据）
      final userData = await getUserPlayData();
      if (userData == null || userData['records'] == null) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
      }

      final chartsData = Map<String, dynamic>.from(songDiffData['charts'] as Map);
      final records = userData['records'] as List;

      // 创建记录映射，便于查找
      Map<String, Map<String, dynamic>> recordMap = {};
      for (var record in records) {
        String key = '${record['song_id']}_${record['level_index']}';
        recordMap[key] = Map<String, dynamic>.from(record as Map);
      }

      // 存储计算结果（分离sd和dx）
      List<Map<String, dynamic>> diffSdSongs = [];  // Best35 - 非当前版本
      List<Map<String, dynamic>> diffDxSongs = [];  // Best15 - 当前版本

      // 处理SD数据（Best35）
      if (best50Data['charts']?['sd'] is List) {
        for (var chart in (best50Data['charts']['sd'] as List)) {
          await _processChart(Map<String, dynamic>.from(chart as Map), recordMap, chartsData, diffSdSongs);
        }
      }

      // 处理DX数据（Best15）
      if (best50Data['charts']?['dx'] is List) {
        for (var chart in (best50Data['charts']['dx'] as List)) {
          await _processChart(Map<String, dynamic>.from(chart as Map), recordMap, chartsData, diffDxSongs);
        }
      }

      // 分别按diffRating降序排序
      diffSdSongs.sort((a, b) => b['diffRating'].compareTo(a['diffRating']));
      diffDxSongs.sort((a, b) => b['diffRating'].compareTo(a['diffRating']));

      // 合并结果
      List<Map<String, dynamic>> diffBest50 = [...diffSdSongs, ...diffDxSongs];

      // 计算DiffRating总和
      int diffRatingSum = diffBest50.fold(0, (sum, item) => sum + (item['diffRating'] as int));

      // 计算与Best50的差值
      int best50Sum = userData['rating'] ?? (best50Data['rating'] ?? 0);
      int best50Diff = diffRatingSum - best50Sum;

      return {
        'diffRatingSum': diffRatingSum,
        'diffBest50': diffBest50,
        'diffSdSongs': diffSdSongs,
        'diffDxSongs': diffDxSongs,
        'best50Diff': best50Diff,
      };
    } catch (e) {
      debugPrint('计算DiffBest50数据失败: $e');
      return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
    }
  }

  // 模式C：根据is_new字段分别在非当前版本/当前版本中取拟合Rating前35/15（UTAGE不参与）
  Future<Map<String, dynamic>> calculateDiffBest50ModeC() async {
    try {
      // 加载歌曲难度数据
      final songDiffData = await loadSongDiffData();
      if (songDiffData.isEmpty) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
      }

      // 获取用户游玩记录
      final userData = await getUserPlayData();
      if (userData == null || userData['records'] == null) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
      }

      // 获取全量歌曲数据用于判断is_new
      final musicDataManager = MaimaiMusicDataManager();
      final songs = await musicDataManager.getCachedSongs();
      if (songs == null) {
        return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
      }

      // 构建歌曲ID到is_new的映射
      Map<String, bool> songIsNewMap = {};
      for (var song in songs) {
        songIsNewMap[song.id] = song.basicInfo.isNew;
      }

      final chartsData = songDiffData['charts'];
      final records = userData['records'] as List;

      // 存储计算结果（分离非当前版本和当前版本）
      List<Map<String, dynamic>> diffSdSongs = [];  // 非当前版本（is_new=false）
      List<Map<String, dynamic>> diffDxSongs = [];  // 当前版本（is_new=true）

      // 遍历用户游玩记录
      for (var record in records) {
        int songId = record['song_id'];
        int levelIndex = record['level_index'];
        double achievements = double.parse(record['achievements'].toString());
        String type = record['type'] ?? '';

        // 跳过6位数ID的歌曲（UTAGE）
        if (songId.toString().length == 6) {
          continue;
        }

        // 获取歌曲的is_new状态
        bool isNew = songIsNewMap[songId.toString()] ?? false;

        // 查找对应的拟合定数（没有拟合定数则按0计算）
        double fitDiff = 0.0;
        if (chartsData.containsKey(songId.toString())) {
          final songCharts = chartsData[songId.toString()];
          if (levelIndex < songCharts.length) {
            fitDiff = songCharts[levelIndex]['fit_diff'] ?? 0.0;
          }
        }

        // 计算DiffRating（没有拟合定数时fitDiff为0，Rating也为0）
        int diffRating = calculateSingleRating(fitDiff, achievements);

        // 根据is_new分类
        Map<String, dynamic> songData = {
          'song_id': songId,
          'level_index': levelIndex,
          'title': record['title'],
          'type': type,
          'ds': record['ds'],
          'achievements': achievements,
          'dxScore': record['dxScore'],
          'fc': record['fc'],
          'fs': record['fs'],
          'rate': record['rate'],
          'ra': record['ra'],
          'diffRating': diffRating,
          'fit_diff': fitDiff,
        };

        if (isNew) {
          diffDxSongs.add(songData);
        } else {
          diffSdSongs.add(songData);
        }
      }

      // 分别按diffRating降序排序
      diffSdSongs.sort((a, b) => b['diffRating'].compareTo(a['diffRating']));
      diffDxSongs.sort((a, b) => b['diffRating'].compareTo(a['diffRating']));

      // 非当前版本取前35首，当前版本取前15首
      if (diffSdSongs.length > 35) {
        diffSdSongs = diffSdSongs.sublist(0, 35);
      }
      if (diffDxSongs.length > 15) {
        diffDxSongs = diffDxSongs.sublist(0, 15);
      }

      // 合并结果
      List<Map<String, dynamic>> diffBest50 = [...diffSdSongs, ...diffDxSongs];

      // 计算DiffRating总和
      int diffRatingSum = diffBest50.fold(0, (sum, item) => sum + (item['diffRating'] as int));

      // 计算与Best50的差值
      int best50Sum = userData['rating'] ?? 0;
      int best50Diff = diffRatingSum - best50Sum;

      return {
        'diffRatingSum': diffRatingSum,
        'diffBest50': diffBest50,
        'diffSdSongs': diffSdSongs,
        'diffDxSongs': diffDxSongs,
        'best50Diff': best50Diff,
      };
    } catch (e) {
      debugPrint('计算DiffBest50数据失败: $e');
      return {'diffRatingSum': 0, 'diffBest50': [], 'diffSdSongs': [], 'diffDxSongs': [], 'best50Diff': 0};
    }
  }

  // 处理单个图表数据
  Future<void> _processChart(
    Map<String, dynamic> chart,
    Map<String, Map<String, dynamic>> recordMap,
    Map<String, dynamic> chartsData,
    List<Map<String, dynamic>> resultList,
  ) async {
    int songId = chart['song_id'] ?? 0;
    int levelIndex = chart['level_index'] ?? 0;
    String key = '${songId}_${levelIndex}';

    // 从用户记录中获取详细数据
    var record = recordMap[key];
    if (record == null) {
      return;
    }

    double achievements = double.parse(record['achievements'].toString());

    // 查找对应的拟合定数
    double fitDiff = 0.0;
    bool useOfficialDiff = false;
    if (chartsData.containsKey(songId.toString())) {
      final songCharts = List<Map<String, dynamic>>.from(chartsData[songId.toString()] as List);
      if (levelIndex < songCharts.length) {
        fitDiff = songCharts[levelIndex]['fit_diff'] ?? 0.0;
      }
    }

    // 如果拟合定数不存在，使用官方定数
    if (fitDiff == 0.0) {
      fitDiff = double.tryParse((record['ds'] ?? chart['ds'] ?? '0').toString()) ?? 0.0;
      useOfficialDiff = true;
    }

    // 计算DiffRating
    int diffRating = calculateSingleRating(fitDiff, achievements);

    // 添加到结果列表
    resultList.add({
      'song_id': songId,
      'level_index': levelIndex,
      'title': record['title'] ?? chart['title'] ?? '',
      'type': record['type'] ?? chart['type'] ?? '',
      'ds': record['ds'] ?? chart['ds'] ?? 0,
      'achievements': achievements,
      'dxScore': record['dxScore'] ?? chart['dxScore'] ?? 0,
      'fc': record['fc'] ?? chart['fc'] ?? '',
      'fs': record['fs'] ?? chart['fs'] ?? '',
      'rate': record['rate'] ?? chart['rate'] ?? '',
      'ra': record['ra'] ?? chart['ra'] ?? 0,
      'diffRating': diffRating,
      'fit_diff': fitDiff,
      'use_official_diff': useOfficialDiff, // 标记是否使用了官方定数
    });
  }
}