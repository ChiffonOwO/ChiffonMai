import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class KaleidXScopeInfoServicePURPLE {
  // 单例模式
  static final KaleidXScopeInfoServicePURPLE _instance = KaleidXScopeInfoServicePURPLE._internal();
  factory KaleidXScopeInfoServicePURPLE() => _instance;
  KaleidXScopeInfoServicePURPLE._internal();

  // 紫门挑战歌曲ID列表（曲目池）
  static const List<int> purpleGateSongIds = [
    328, 403, 457, 458, 532, 533, 559, 568, 613, 626, 673,
    11001, 11002, 11104, 11105, 11168, 11169, 11170, 11365, 11380, 11381,
    11456, 11532, 11533, 11613, 11614, 11747, 11748
  ];

  // Track1 歌曲ID列表
  static const List<int> track1SongIds = [
    328, 403, 457, 458, 532, 533, 559, 568, 613, 626, 673
  ];

  // Track2 歌曲ID列表
  static const List<int> track2SongIds = [
    11001, 11002, 11104, 11105, 11168, 11169, 11170, 11365, 11380, 11381,
    11456, 11532, 11533, 11613, 11614, 11747, 11748
  ];

  // Track3 歌曲ID列表（隐藏歌曲）
  static const List<int> track3SongIds = [11749];

  // 紫门挑战数据
  static const purpleGateChallenge = {
    'name': '紫门挑战',
    'phases': [
      {'startDate': '03-25', 'endDate': '03-27', 'type': 'MASTER', 'lifeTarget': 1},
      {'startDate': '03-28', 'endDate': '03-30', 'type': 'MASTER', 'lifeTarget': 10},
      {'startDate': '03-31', 'endDate': '04-02', 'type': 'MASTER', 'lifeTarget': 30},
      {'startDate': '04-03', 'endDate': '04-06', 'type': 'MASTER', 'lifeTarget': 50},
      {'startDate': '04-07', 'endDate': '04-14', 'type': 'EXPERT', 'lifeTarget': 100},
      {'startDate': '04-15', 'endDate': null, 'type': 'BASIC', 'lifeTarget': 999},
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
        print('未找到歌曲ID: $id');
      }
    }

    return result;
  }

  // 获取紫门挑战的歌曲列表
  Future<List<Song>> getPurpleGateSongs() async {
    return await getSongsByIds(purpleGateSongIds);
  }

  // 根据门的类型获取歌曲列表
  Future<List<Song>> getSongsByGateType(String gateType) async {
    switch (gateType) {
      case 'purple':
      case '紫门':
        return await getPurpleGateSongs();
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
      print('加载Track歌曲失败: $e');
    }

    return result;
  }
}