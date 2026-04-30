import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class KaleidXScopeInfoServiceBLACK {
  // 单例模式
  static final KaleidXScopeInfoServiceBLACK _instance = KaleidXScopeInfoServiceBLACK._internal();
  factory KaleidXScopeInfoServiceBLACK() => _instance;
  KaleidXScopeInfoServiceBLACK._internal();

  // 黑门挑战歌曲ID列表（曲目池）
  static const List<int> blackGateSongIds = [
    11023, 11106, 11221, 11222, 11300, 11374, 11458, 11523, 11619, 11663, 11746
  ];

  // Track1 歌曲ID列表
  static const List<int> track1SongIds = [
    11019, 11020, 11021, 11022, 11090, 11091, 11092, 11157, 11158, 11159,
    11232, 11233, 11234, 11304, 11305, 11306, 11382, 11383, 11384, 11459,
    11460, 11461, 11615, 11616, 11617, 11674, 11675, 11676, 11750, 11751
  ];

  // Track2 歌曲ID列表
  static const List<int> track2SongIds = [
    11023, 11089, 11160, 11235, 11307, 11385, 11462, 11618, 11677, 11752
  ];

  // Track3 歌曲ID列表（隐藏歌曲）
  static const List<int> track3SongIds = [11753];

  // 黑门挑战数据
  static const blackGateChallenge = {
    'name': '黑门挑战',
    'phases': [
      {'day': 1, 'startDate': '04-28', 'endDate': '04-30', 'type': 'MASTER', 'lifeTarget': 1},
      {'day': 4, 'startDate': '05-01', 'endDate': '05-03', 'type': 'MASTER', 'lifeTarget': 10},
      {'day': 7, 'startDate': '05-04', 'endDate': '05-06', 'type': 'MASTER', 'lifeTarget': 30},
      {'day': 10, 'startDate': '05-07', 'endDate': '05-10', 'type': 'MASTER', 'lifeTarget': 50},
      {'day': 14, 'startDate': '05-11', 'endDate': '05-17', 'type': 'EXPERT', 'lifeTarget': 100},
      {'day': 21, 'startDate': '05-18', 'type': 'BASIC', 'lifeTarget': 999},
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

  // 获取黑门挑战的歌曲列表
  Future<List<Song>> getBlackGateSongs() async {
    return await getSongsByIds(blackGateSongIds);
  }

  // 根据门的类型获取歌曲列表
  Future<List<Song>> getSongsByGateType(String gateType) async {
    switch (gateType) {
      case 'black':
      case '黑门':
        return await getBlackGateSongs();
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