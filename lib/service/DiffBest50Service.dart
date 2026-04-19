import '../manager/UserPlayDataManager.dart';
import '../manager/DiffMusicDataManager.dart';

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
      print('加载歌曲难度数据失败: $e');
      return {};
    }
  }

  // 获取用户游玩记录
  Future<Map<String, dynamic>?> getUserPlayData() async {
    try {
      final userPlayDataManager = UserPlayDataManager();
      return await userPlayDataManager.getCachedUserPlayData();
    } catch (e) {
      print('获取用户游玩数据失败: $e');
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

  // 计算DiffBest50数据
  Future<Map<String, dynamic>> calculateDiffBest50() async {
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
      print('计算DiffBest50数据失败: $e');
      return {'diffRatingSum': 0, 'diffBest50': [], 'best50Diff': 0};
    }
  }
}