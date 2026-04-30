import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class KaleidXScopeInfoServiceWHITE {
  // 单例模式
  static final KaleidXScopeInfoServiceWHITE _instance = KaleidXScopeInfoServiceWHITE._internal();
  factory KaleidXScopeInfoServiceWHITE() => _instance;
  KaleidXScopeInfoServiceWHITE._internal();

  // 白门挑战歌曲ID列表
  static const List<int> whiteGateSongIds = [
    11102, 11234, 11300, 11529, 11542, 11612
  ];

  // Track1 歌曲ID列表
  static const List<int> track1SongIds = [
    11027, 11101, 11103, 11166, 11167, 11236, 11237, 11301,
    11303, 11387, 11388, 11386, 11467, 11468, 11469, 11682,
    11683, 11684, 11742, 11743
  ];

  // Track2 歌曲ID列表
  static const List<int> track2SongIds = [
    11026, 11102, 11165, 11238, 11302, 11389, 11470, 11685, 11744
  ];

  // Track3 歌曲ID列表（隐藏歌曲）
  static const List<int> track3SongIds = [11745];

  // 白门挑战数据
  static const whiteGateChallenge = {
    'name': '白门挑战',
    'phases': [
      {'startDate': '02-10', 'endDate': '02-12', 'type': 'MASTER', 'target': 135, 'lifeTarget': 1},
      {'startDate': '02-13', 'endDate': '02-15', 'type': 'MASTER', 'target': 135, 'lifeTarget': 10},
      {'startDate': '02-16', 'endDate': '02-18', 'type': 'MASTER', 'target': 135, 'lifeTarget': 30},
      {'startDate': '02-19', 'endDate': '02-22', 'type': 'MASTER', 'target': 135, 'lifeTarget': 50},
      {'startDate': '02-23', 'endDate': '03-01', 'type': 'EXPERT', 'target': 135, 'lifeTarget': 100},
      {'startDate': '03-02', 'endDate': null, 'type': 'BASIC', 'target': 135, 'lifeTarget': 999},
    ],
  };

  static const whiteGatePerfectChallenge = {
    'name': '完美挑战（Deicide）',
    'phases': [
      {'startDate': '02-10', 'endDate': '02-16', 'type': 'MASTER', 'target': 1, 'lifeTarget': 1},
      {'startDate': '02-17', 'endDate': '02-23', 'type': 'MASTER', 'target': 1, 'lifeTarget': 10},
      {'startDate': '02-24', 'endDate': '03-02', 'type': 'EXPERT', 'target': 1, 'lifeTarget': 50},
      {'startDate': '03-03', 'endDate': '03-09', 'type': 'BASIC', 'target': 1, 'lifeTarget': 100},
      {'startDate': '03-10', 'endDate': null, 'type': 'BASIC', 'target': 1, 'lifeTarget': 300},
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

  // 获取白门挑战的歌曲列表
  Future<List<Song>> getWhiteGateSongs() async {
    return await getSongsByIds(whiteGateSongIds);
  }

  // 根据门的类型获取歌曲列表
  Future<List<Song>> getSongsByGateType(String gateType) async {
    switch (gateType) {
      case 'white':
      case '白门':
        return await getWhiteGateSongs();
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