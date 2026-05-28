/**
 * 落雪数据 → 水鱼数据工具类
 * */
import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/entity/DivingFish/RecordItem.dart';
import 'package:my_first_flutter_app/entity/LuoXue/Collection.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/entity/LuoXue/LuoXueScore.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';


class LuoXueToDivingFishUtil {
  // 解码 Unicode 编码的字符串
  static String decodeUnicode(String input) {
    if (input.isEmpty) {
      return input;
    }

    RegExp unicodeRegExp = RegExp(r'\\u([0-9a-fA-F]{4})');
    return input.replaceAllMapped(unicodeRegExp, (match) {
      int code = int.parse(match.group(1)!, radix: 16);
      return String.fromCharCode(code);
    });
  }

  // 根据 Collection 对象中的 required.songs 列表，从缓存中查找相应的歌曲信息
  static Future<Map<CollectionRequiredSong, Song?>> getSongsFromCache(Collection collection) async {
    // 创建结果映射，键为 CollectionRequiredSong，值为对应的 Song 对象
    final Map<CollectionRequiredSong, Song?> result = {};
    
    // 检查 Collection 对象是否有 required 列表
    if (collection.required == null || collection.required!.isEmpty ) {
      return result;
    }

    // 获取缓存的歌曲数据
    final songs = await MaimaiMusicDataManager().getCachedSongs();
    if (songs == null || songs.isEmpty) {
      return result;
    }

    // 遍历 required 列表
    for (final requiredItem in collection.required!) {
      // 检查是否有 songs 列表
      if (requiredItem.songs == null || requiredItem.songs!.isEmpty) {
        continue;
      }

      // 遍历 songs 列表
      for (final requiredSong in requiredItem.songs!) {
        Song? matchedSong;
        try {
          // 根据 title 和 type 查找对应的歌曲
              matchedSong = songs.firstWhere(
                (song) {
                  final decodedTitle = decodeUnicode(song.title);
                  final decodedType = decodeUnicode(song.type).toLowerCase();
                  final targetTitle = requiredSong.title;
                  final targetType = requiredSong.type.toLowerCase();

                  // 处理类型匹配：
                  // - Collections中的 standard 对应 缓存中的 SD
                  // - Collections中的 dx 对应 缓存中的 DX
                  bool typeMatch = false;
                  if (targetType == 'standard' && decodedType == 'sd') {
                    typeMatch = true;
                  } else if (targetType == 'dx' && decodedType == 'dx') {
                    typeMatch = true;
                  } else if (targetType == decodedType) {
                    typeMatch = true;
                  }

                  return decodedTitle == targetTitle && typeMatch;
                },
              );
        } catch (e) {
          matchedSong = null;
        }

        // 添加到结果映射中
        result[requiredSong] = matchedSong;
      }
    }

    return result;
  }
  
  // 简化版本：直接返回匹配的歌曲列表
  static Future<List<Song>> getMatchedSongs(Collection collection) async {
    final songMap = await getSongsFromCache(collection);
    final matchedList = songMap.values.where((song) => song != null).cast<Song>().toList();
    return matchedList;
  }


  // 根据 levelIndex 获取对应的难度标签
  static String _getLevelLabel(int levelIndex) {
    switch (levelIndex) {
      case 0:
        return 'Basic';
      case 1:
        return 'Advanced';
      case 2:
        return 'Expert';
      case 3:
        return 'Master';
      case 4:
        return 'Re:MASTER';
      default:
        return '';
    }
  }
  
  // 根据类型字符串获取标准化的类型标签
  static String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'standard':
        return 'SD';
      case 'dx':
        return 'DX';
      case 'utage':
        return 'UTAGE';
      default:
        return type;
    }
  }
  
  // 转换 LuoXueScore 到 RecordItem 对象（同步版本，需要提前获取歌曲缓存）
  static RecordItem toRecordItem(LuoXueScore score, {Song? song}) {
    // 根据 levelIndex 生成难度标签
    String levelLabel = _getLevelLabel(score.levelIndex.toInt());
    
    // 根据 levelIndex 获取对应的 ds 值
    double ds = 0.0;
    if (song != null) {
      int index = score.levelIndex.toInt();
      if (index >= 0 && index < song.ds.length) {
        ds = song.ds[index];
      }
    }
    
    // 获取 songId：优先使用缓存中歌曲的 id，否则使用原始 score.id
    int songId = score.id.toInt();
    if (song != null && song.id.isNotEmpty) {
      int? parsedId = int.tryParse(song.id);
      if (parsedId != null) {
        songId = parsedId;
      }
    }
    
    return RecordItem(
      achievements: score.achievements,
      ds: ds,
      dxScore: score.dxScore.floor(),
      fc: score.fc ?? '',
      fs: score.fs ?? '',
      level: score.level,
      levelIndex: score.levelIndex.toInt(),
      levelLabel: levelLabel,
      ra: score.dxRating.toInt(),
      rate: score.rate,
      songId: songId,
      title: decodeUnicode(score.songName),
      type: _getTypeLabel(score.type),
    );
  }
  
  // 转换 LuoXueScore 到 RecordItem 对象（异步版本，自动从缓存查找歌曲）
  static Future<RecordItem> toRecordItemAsync(LuoXueScore score) async {
    // 从缓存中查找对应的歌曲
    Song? song;
    try {
      final songs = await MaimaiMusicDataManager().getCachedSongs();
      if (songs != null && songs.isNotEmpty) {
        song = songs.firstWhere(
          (s) => s.basicInfo.title == score.songName && s.type == _getTypeLabel(score.type),
          orElse: () => Song(
            id: '',
            title: '',
            type: '',
            ds: [],
            level: [],
            cids: [],
            charts: [],
            basicInfo: BasicInfo(
              title: '',
              artist: '',
              genre: '',
              bpm: 0,
              releaseDate: '',
              from: '',
              isNew: false,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('查找歌曲失败: $e');
    }
    
    return toRecordItem(score, song: song);
  }
}