/**
 * 落雪id → 水鱼数据工具类
 * */
import 'package:my_first_flutter_app/entity/Collection.dart';
import 'package:my_first_flutter_app/entity/Song.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';


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
}