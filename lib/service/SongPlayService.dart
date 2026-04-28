import 'dart:math';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/LuoXueSongsManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class SongPlayService {
  // 单例模式
  static final SongPlayService _instance = SongPlayService._internal();
  factory SongPlayService() => _instance;
  SongPlayService._internal();

  // 加载所有落雪歌曲数据
  Future<Map<Song, dynamic>?> loadAllSongs() async {
    try {
      // 获取落雪歌曲数据
      final luoXueSongsManager = LuoXueSongsManager();
      final luoXueSongEntity = await luoXueSongsManager.getLuoXueSongs();
      
      if (luoXueSongEntity == null || luoXueSongEntity.songs.isEmpty) {
        return null;
      }

      // 获取缓存的歌曲数据
      final maimaiMusicManager = MaimaiMusicDataManager();
      List<Song> cachedSongs = [];
      
      if (await maimaiMusicManager.hasCachedData()) {
        cachedSongs = await maimaiMusicManager.getCachedSongs() ?? [];
      }

      // 构建歌曲映射
      final Map<Song, dynamic> songMap = {};
      
      for (final luoXueSong in luoXueSongEntity.songs) {
        // 检查是否有standard或dx难度
        bool hasStandard = luoXueSong.difficulties.standard != null && luoXueSong.difficulties.standard!.isNotEmpty;
        bool hasDx = luoXueSong.difficulties.dx != null && luoXueSong.difficulties.dx!.isNotEmpty;
        
        if (!hasStandard && !hasDx) {
          continue;
        }

        // 随机选择类型
        String selectedType = hasStandard && hasDx 
            ? (Random().nextBool() ? 'SD' : 'DX') 
            : (hasStandard ? 'SD' : 'DX');

        // 查找对应的缓存歌曲
        Song? matchedSong;
        try {
          matchedSong = cachedSongs.firstWhere(
            (song) => song.basicInfo.title == luoXueSong.title && song.type == selectedType,
            orElse: () => Song(
              id: '',
              title: luoXueSong.title,
              type: selectedType,
              ds: [],
              level: [],
              cids: [],
              charts: [],
              basicInfo: BasicInfo(
                title: luoXueSong.title,
                artist: luoXueSong.artist,
                genre: luoXueSong.genre,
                bpm: luoXueSong.bpm,
                releaseDate: '',
                from: luoXueSong.version.toString(),
                isNew: false,
              ),
            ),
          );
        } catch (e) {
          // 如果查找失败，创建一个默认歌曲
          matchedSong = Song(
            id: '',
            title: luoXueSong.title,
            type: selectedType,
            ds: [],
            level: [],
            cids: [],
            charts: [],
            basicInfo: BasicInfo(
              title: luoXueSong.title,
              artist: luoXueSong.artist,
              genre: luoXueSong.genre,
              bpm: luoXueSong.bpm,
              releaseDate: '',
              from: luoXueSong.version.toString(),
              isNew: false,
            ),
          );
        }

        // 将落雪歌曲信息与缓存歌曲关联
        songMap[matchedSong] = {
          'luoXueId': luoXueSong.id.toString(),
          'type': selectedType,
        };
      }

      return songMap;
    } catch (e) {
      print('加载歌曲数据失败: $e');
      return null;
    }
  }

  // 根据歌曲标题和类型查找落雪歌曲ID
  Future<String?> findLuoXueSongId(String songTitle, String songType) async {
    try {
      final songMap = await loadAllSongs();
      if (songMap == null || songMap.isEmpty) {
        return null;
      }

      // 查找匹配的歌曲
      for (var entry in songMap.entries) {
        final song = entry.key;
        if (song.basicInfo.title == songTitle && song.type == songType) {
          var luoXueId = entry.value['luoXueId'];
          return luoXueId.toString();
        }
      }

      return null;
    } catch (e) {
      print('查找落雪歌曲ID失败: $e');
      return null;
    }
  }

  // 根据落雪歌曲ID获取歌曲信息
  Future<Map<String, dynamic>?> getSongInfoByLuoXueId(String luoXueId) async {
    try {
      // 获取落雪歌曲数据
      final luoXueSongsManager = LuoXueSongsManager();
      final luoXueSongEntity = await luoXueSongsManager.getLuoXueSongs();
      
      if (luoXueSongEntity == null || luoXueSongEntity.songs.isEmpty) {
        return null;
      }

      // 查找匹配的落雪歌曲
      final luoXueSong = luoXueSongEntity.songs.firstWhere(
        (song) => song.id.toString() == luoXueId,
      );// 获取缓存的歌曲数据
      final maimaiMusicManager = MaimaiMusicDataManager();
      List<Song> cachedSongs = [];
      
      if (await maimaiMusicManager.hasCachedData()) {
        cachedSongs = await maimaiMusicManager.getCachedSongs() ?? [];
      }

      // 查找对应的缓存歌曲
      Song? matchedSong;
      try {
        // 尝试查找SD或DX类型的歌曲
        matchedSong = cachedSongs.firstWhere(
          (song) => song.basicInfo.title == luoXueSong.title,
        );
      } catch (e) {
        // 查找失败
      }

      return {
        'luoXueSong': luoXueSong,
        'maimaiSong': matchedSong,
      };
    } catch (e) {
      print('获取歌曲信息失败: $e');
      return null;
    }
  }
}