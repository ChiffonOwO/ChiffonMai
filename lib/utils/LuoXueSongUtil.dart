import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:just_audio/just_audio.dart';
import '../constant/CacheTimestampConstant.dart';

class LuoXueSongUtil {
  // 单例模式
  static final LuoXueSongUtil _instance = LuoXueSongUtil._internal();
  factory LuoXueSongUtil() => _instance;
  LuoXueSongUtil._internal();

  // 音乐文件基础URL
  static const String _baseUrl = 'https://assets2.lxns.net/maimai/music/';
  // 音乐文件扩展名
  static const String _fileExtension = '.mp3';

  // 自定义缓存管理器
  final CacheManager _cacheManager = CacheManager(
    Config(
      'music_cache',
      stalePeriod: CacheTimestampConstant.luoxueSongDuration,
      maxNrOfCacheObjects: 1000, // 最多缓存1000个文件
    ),
  );

  // 获取音乐文件URL
  String getMusicUrl(String musicId) {
    return '$_baseUrl$musicId$_fileExtension';
  }

  // 检查音乐文件是否已缓存
  Future<bool> isMusicCached(String musicId) async {
    try {
      final url = getMusicUrl(musicId);
      final fileInfo = await _cacheManager.getFileFromCache(url);
      return fileInfo != null;
    } catch (e) {
      debugPrint('Error checking if music is cached: $e');
      return false;
    }
  }

  // 下载并缓存音乐文件
  Future<File?> downloadAndCacheMusic(String musicId) async {
    try {
      final url = getMusicUrl(musicId);
      final file = await _cacheManager.downloadFile(url);
      return file.file;
    } catch (e) {
      debugPrint('Error downloading music: $e');
      return null;
    }
  }

  // 获取音乐文件（优先使用缓存）
  Future<File?> getMusicFile(String musicId) async {
    try {
      final url = getMusicUrl(musicId);
      final fileInfo = await _cacheManager.getFileFromCache(url);
      
      if (fileInfo != null) {
        return fileInfo.file;
      } else {
        // 下载并缓存
        final file = await _cacheManager.downloadFile(url);
        return file.file;
      }
    } catch (e) {
      debugPrint('Error getting music file: $e');
      return null;
    }
  }

  // 清除音乐缓存
  Future<void> clearMusicCache() async {
    try {
      await _cacheManager.emptyCache();
    } catch (e) {
      debugPrint('Error clearing music cache: $e');
    }
  }

  // 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      return 0;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  // 格式化文件大小
  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  // 获取歌曲时长
  Future<Duration?> getSongDuration(String musicId) async {
    try {
      final file = await getMusicFile(musicId);
      if (file == null) return null;

      final player = AudioPlayer();
      await player.setFilePath(file.path);
      final duration = await player.duration;
      await player.dispose();
      return duration;
    } catch (e) {
      debugPrint('Error getting song duration: $e');
      return null;
    }
  }
}