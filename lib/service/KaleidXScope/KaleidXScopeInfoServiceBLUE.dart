import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class KaleidXScopeInfoServiceBLUE {
  // 单例模式
  static final KaleidXScopeInfoServiceBLUE _instance = KaleidXScopeInfoServiceBLUE._internal();
  factory KaleidXScopeInfoServiceBLUE() => _instance;
  KaleidXScopeInfoServiceBLUE._internal();

  // 蓝色之门的歌曲ID列表
  static const List<int> blueGateSongIds = [
    11009, 11008, 11100, 11097, 11098, 11099, 11163, 11162, 11161, 11228,
    11229, 11231, 11739, 11463, 11464, 11465, 11538, 11539, 11541, 11620,
    11622, 11623, 11737, 11738, 11164, 11230, 11466, 11540, 11621
  ];

  // Track1 可能的歌曲ID
  static const List<int> track1SongIds = [
    11009, 11008, 11100, 11097, 11098, 11099, 11163, 11162, 11161, 11228,
    11229, 11231, 11463, 11464, 11465, 11538, 11539, 11541, 11620,
    11622, 11623, 11737, 11738
  ];

  // Track2 可能的歌曲ID
  static const List<int> track2SongIds = [
    11164, 11230, 11466, 11540, 11621, 11739
  ];

  // Track3 可能的歌曲ID
  static const List<int> track3SongIds = [
    11740
  ];

  // 蓝色之门挑战数据
  static const blueGateChallenge = {
    'name': '蓝色之门挑战',
    'phases': [
      {'startDate': '01-23', 'endDate': '01-25', 'type': 'MASTER', 'target': 1, 'lifeTarget': 1},
      {'startDate': '01-26', 'endDate': '01-28', 'type': 'MASTER', 'target': 10, 'lifeTarget': 10},
      {'startDate': '01-29', 'endDate': '01-31', 'type': 'MASTER', 'target': 30, 'lifeTarget': 30},
      {'startDate': '02-01', 'endDate': '02-04', 'type': 'MASTER', 'target': 50, 'lifeTarget': 50},
      {'startDate': '02-05', 'endDate': '02-11', 'type': 'EXPERT', 'target': 100, 'lifeTarget': 100},
      {'startDate': '02-12', 'endDate': null, 'type': 'BASIC', 'target': 999, 'lifeTarget': 999},
    ],
  };

  static const skyStreetChallenge = {
    'name': '天空街完美挑战',
    'phases': [
      {'startDate': '01-30', 'endDate': '02-05', 'type': 'MASTER', 'target': 10, 'lifeTarget': 10},
      {'startDate': '02-06', 'endDate': '02-12', 'type': 'EXPERT', 'target': 50, 'lifeTarget': 50},
      {'startDate': '02-13', 'endDate': '02-19', 'type': 'EXPERT', 'target': 100, 'lifeTarget': 100},
      {'startDate': '02-19', 'endDate': null, 'type': 'BASIC', 'target': 300, 'lifeTarget': 300},
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
        // 未找到对应歌曲，跳过
        debugPrint('未找到歌曲ID: $id');
      }
    }

    return result;
  }

  // 获取蓝色之门的歌曲列表
  Future<List<Song>> getBlueGateSongs() async {
    return await getSongsByIds(blueGateSongIds);
  }

  // 根据门的类型获取歌曲列表
  Future<List<Song>> getSongsByGateType(String gateType) async {
    // 当前只有蓝色之门有歌曲数据，其他门可以扩展
    switch (gateType) {
      case 'blue':
      case '蓝色之门':
        return await getBlueGateSongs();
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