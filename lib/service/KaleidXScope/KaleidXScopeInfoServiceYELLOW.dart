import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';

class KaleidXScopeInfoServiceYELLOW {
  // 单例模式
  static final KaleidXScopeInfoServiceYELLOW _instance = KaleidXScopeInfoServiceYELLOW._internal();
  factory KaleidXScopeInfoServiceYELLOW() => _instance;
  KaleidXScopeInfoServiceYELLOW._internal();

  // 黄色之门歌曲ID列表（曲目池/钥匙）
  static const List<int> yellowGateSongIds = [
    11003, 11095, 11152, 11224, 11296, 11375, 11452, 11529, 11608, 11669, 11736, 11806
  ];

  // Track1 歌曲ID列表（启程区域随机选曲）
  static const List<int> track1SongIds = [
    11003, 11007, 11006, 11005, 11094, 11095, 11096, 11152, 11153, 11154,
    11224, 11225, 11226, 11296, 11297, 11298, 11375, 11376, 11377, 11452,
    11453, 11454, 11526, 11527, 11528, 11669, 11670, 11671, 11806, 11807
  ];

  // Track2 歌曲ID列表（启程区域随机完美挑战曲、MAXRAGE、UniTas）
  static const List<int> track2SongIds = [
    11004, 11093, 11155, 11227, 11299, 11378, 11455, 11529, 11611, 11672, 11808
  ];

  // Track3 歌曲ID列表（隐藏歌曲）
  static const List<int> track3SongIds = [11809];

  // 完美挑战数据
  static const yellowPerfectChallenge = {
    'name': '完美挑战',
    'phases': [
      {'startDate': '6.10', 'endDate': '6.10', 'type': 'MASTER', 'lifeTarget': 1},
      {'startDate': '6.11', 'endDate': '6.12', 'type': 'MASTER', 'lifeTarget': 10},
      {'startDate': '6.13', 'endDate': '6.16', 'type': 'EXPERT', 'lifeTarget': 50},
      {'startDate': '6.17', 'endDate': '6.23', 'type': 'BASIC', 'lifeTarget': 100},
      {'startDate': '6.24', 'endDate': null, 'type': 'BASIC', 'lifeTarget': 300},
    ],
  };

  // 黄门挑战数据
  static const yellowGateChallenge = {
    'name': '黄门挑战',
    'phases': [
      {'startDate': '6.10', 'endDate': '6.12', 'type': 'MASTER', 'lifeTarget': 1},
      {'startDate': '6.13', 'endDate': '6.16', 'type': 'MASTER', 'lifeTarget': 10},
      {'startDate': '6.17', 'endDate': '6.18', 'type': 'MASTER', 'lifeTarget': 30},
      {'startDate': '6.19', 'endDate': '6.23', 'type': 'MASTER', 'lifeTarget': 50},
      {'startDate': '6.24', 'endDate': '6.29', 'type': 'EXPERT', 'lifeTarget': 100},
      {'startDate': '6.30', 'endDate': null, 'type': 'BASIC', 'lifeTarget': 999},
    ],
  };

  // 从缓存中获取指定ID列表的歌曲
  Future<List<Song>> getSongsByIds(List<int> songIds) async {
    final List<Song> result = [];
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    
    if (songs == null) {
      return result;
    }

    for (final id in songIds) {
      try {
        final song = songs.firstWhere((s) => int.parse(s.id) == id);
        result.add(song);
      } catch (e) {
        debugPrint('未找到歌曲ID: $id');
      }
    }

    return result;
  }

  // 获取黄色之门的歌曲列表
  Future<List<Song>> getYellowGateSongs() async {
    return await getSongsByIds(yellowGateSongIds);
  }

  // 根据门的类型获取歌曲列表
  Future<List<Song>> getSongsByGateType(String gateType) async {
    switch (gateType) {
      case 'yellow':
      case '黄色之门':
        return await getYellowGateSongs();
      default:
        return [];
    }
  }

  // 加载Track歌曲
  Future<Map<String, List<Song>>> loadTrackSongs() async {
    final Map<String, List<Song>> result = {
      'track1': [],
      'track2': [],
      'track3': [],
    };

    try {
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return result;

      // Track1
      result['track1'] = track1SongIds
          .map((id) => allSongs.firstWhere(
                (s) => int.parse(s.id) == id,
              ))
          .where((s) => s != null)
          .cast<Song>()
          .toList();

      // Track2
      result['track2'] = track2SongIds
          .map((id) => allSongs.firstWhere(
                (s) => int.parse(s.id) == id,
              ))
          .where((s) => s != null)
          .cast<Song>()
          .toList();

      // Track3
      result['track3'] = track3SongIds
          .map((id) => allSongs.firstWhere(
                (s) => int.parse(s.id) == id,
              ))
          .where((s) => s != null)
          .cast<Song>()
          .toList();
    } catch (e) {
      debugPrint('加载Track歌曲失败: $e');
    }

    return result;
  }
}