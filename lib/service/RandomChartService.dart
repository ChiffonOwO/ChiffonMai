import 'dart:math';
import 'package:flutter/material.dart';
import 'package:my_first_flutter_app/entity/DivingFish/Song.dart';
import 'package:my_first_flutter_app/manager/DivingFish/MaimaiMusicDataManager.dart';
import 'package:my_first_flutter_app/constant/VersionListConstant.dart';

class RandomChartService {
  // 单例模式
  static final RandomChartService _instance = RandomChartService._internal();
  factory RandomChartService() => _instance;
  RandomChartService._internal();

  // 随机抽取歌曲
  Future<List<Song>> randomDrawSongs({
    int count = 4,
    double? minDs,
    double? maxDs,
    List<String>? versions,
    List<String>? genres,
    bool requireMaster = false,
    bool excludeSixDigitId = false,
  }) async {
    // 获取所有歌曲
    final manager = MaimaiMusicDataManager();
    final allSongs = await manager.getCachedSongs();
    
    debugPrint('[RandomChartService] randomDrawSongs - 开始随机抽歌');
    debugPrint('[RandomChartService] 筛选条件: count=$count, minDs=$minDs, maxDs=$maxDs, requireMaster=$requireMaster, excludeSixDigitId=$excludeSixDigitId');
    debugPrint('[RandomChartService] 版本筛选: ${versions?.length ?? 0} 个版本');
    debugPrint('[RandomChartService] 流派筛选: ${genres?.length ?? 0} 个流派');
    
    if (allSongs == null || allSongs.isEmpty) {
      debugPrint('[RandomChartService] 歌曲列表为空');
      return [];
    }
    
    debugPrint('[RandomChartService] 初始歌曲总数: ${allSongs.length}');

    // 过滤歌曲（排除从maidata追加的歌曲）
    List<Song> filteredSongs = allSongs.where((song) {
      // 过滤掉从maidata追加的歌曲（cids全为0表示从maidata解析）
      if (_isMaidataSong(song)) {
        return false;
      }

      // 排除6位数ID的歌曲
      if (excludeSixDigitId) {
        if (song.id.length == 6) {
          return false;
        }
      }
      
      // 如果要求MASTER难度，检查ds[3]或ds[4]是否存在且满足定数范围
      if (requireMaster) {
        bool hasValidMasterDs = false;
        
        // 检查MASTER难度（索引3）
        if (song.ds.length > 3) {
          double masterDs = song.ds[3];
          bool meetsMin = minDs == null || masterDs >= minDs;
          bool meetsMax = maxDs == null || masterDs <= maxDs;
          if (meetsMin && meetsMax) {
            hasValidMasterDs = true;
          }
        }
        
        // 如果MASTER不满足，检查RE:MASTER难度（索引4）
        if (!hasValidMasterDs && song.ds.length > 4) {
          double remasterDs = song.ds[4];
          bool meetsMin = minDs == null || remasterDs >= minDs;
          bool meetsMax = maxDs == null || remasterDs <= maxDs;
          if (meetsMin && meetsMax) {
            hasValidMasterDs = true;
          }
        }
        
        if (!hasValidMasterDs) {
          return false;
        }
      } else if (minDs != null || maxDs != null) {
        // 非MASTER模式下的定数过滤
        bool hasValidDs = false;
        for (int i = 0; i < song.ds.length; i++) {
          double ds = song.ds[i];
          bool meetsMin = minDs == null || ds >= minDs;
          bool meetsMax = maxDs == null || ds <= maxDs;
          if (meetsMin && meetsMax) {
            hasValidDs = true;
            break;
          }
        }
        if (!hasValidDs) {
          return false;
        }
      }

      // 版本过滤（支持多选）
      if (versions != null && versions.isNotEmpty) {
        if (!versions.contains(song.basicInfo.from)) {
          return false;
        }
      }

      // 流派过滤（支持多选）
      if (genres != null && genres.isNotEmpty) {
        if (!genres.contains(song.basicInfo.genre)) {
          return false;
        }
      }

      return true;
    }).toList();

    debugPrint('[RandomChartService] 过滤后歌曲数: ${filteredSongs.length}');
    
    // 如果过滤后没有歌曲，返回空列表并打印调试信息
    if (filteredSongs.isEmpty) {
      debugPrint('[RandomChartService] 过滤后没有符合条件的歌曲');
      
      // 调试：打印一些符合条件的歌曲信息
      debugPrint('[RandomChartService] 调试：检查定数范围...');
      List<Song> dsTest = allSongs.where((song) {
        if (_isMaidataSong(song)) return false;
        if (excludeSixDigitId && song.id.length == 6) return false;
        if (minDs != null || maxDs != null) {
          for (int i = 0; i < song.ds.length; i++) {
            double ds = song.ds[i];
            bool meetsMin = minDs == null || ds >= minDs;
            bool meetsMax = maxDs == null || ds <= maxDs;
            if (requireMaster) {
              String level = song.level[i];
              if ((level == 'MASTER' || level == 'RE:MASTER') && meetsMin && meetsMax) {
                return true;
              }
            } else if (meetsMin && meetsMax) {
              return true;
            }
          }
          return false;
        }
        return true;
      }).toList();
      debugPrint('[RandomChartService] 仅定数过滤后: ${dsTest.length} 首歌曲');
      
      // 打印一些符合定数条件的歌曲
      if (dsTest.isNotEmpty) {
        debugPrint('[RandomChartService] 示例歌曲（符合定数条件）:');
        for (int i = 0; i < 5 && i < dsTest.length; i++) {
          var song = dsTest[i];
          debugPrint('[RandomChartService]   ${song.id}: ${song.basicInfo.title} - ${song.basicInfo.from} - ${song.basicInfo.genre}');
          for (int j = 0; j < song.ds.length; j++) {
            if ((!requireMaster || (song.level[j] == 'MASTER' || song.level[j] == 'RE:MASTER'))) {
              debugPrint('[RandomChartService]     ${song.level[j]}: ${song.ds[j]}');
            }
          }
        }
      }
      
      // 检查版本和流派匹配
      if (versions != null && versions.isNotEmpty) {
        debugPrint('[RandomChartService] 版本列表: $versions');
      }
      if (genres != null && genres.isNotEmpty) {
        debugPrint('[RandomChartService] 流派列表: $genres');
      }
      
      return [];
    }

    // 随机抽取歌曲
    final random = Random();
    final result = <Song>[];
    final usedIndices = <int>{};

    for (int i = 0; i < count && usedIndices.length < filteredSongs.length; i++) {
      int index;
      do {
        index = random.nextInt(filteredSongs.length);
      } while (usedIndices.contains(index));
      
      usedIndices.add(index);
      result.add(filteredSongs[index]);
    }

    return result;
  }

  // 获取版本列表（排除从maidata追加的歌曲）
  Future<List<String>> getVersionList() async {
    final manager = MaimaiMusicDataManager();
    final allSongs = await manager.getCachedSongs();
    
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }

    final versions = <String>{};
    for (var song in allSongs) {
      // 排除从maidata追加的歌曲（cids全为0表示从maidata解析）
      if (!_isMaidataSong(song)) {
        versions.add(song.basicInfo.from);
      }
    }

    // 按照formatVersion2中的顺序排序版本
    final List<String> sortedVersions = _sortVersionsByFormatOrder(versions.toList());

    return sortedVersions;
  }
  
  // 按照formatVersion2中的顺序排序版本
  List<String> _sortVersionsByFormatOrder(List<String> versions) {
    // 排序版本列表
    versions.sort((a, b) {
      int indexA = VersionListConstant.versionOrderList.indexOf(a);
      int indexB = VersionListConstant.versionOrderList.indexOf(b);
      
      // 如果两个版本都在顺序列表中，按顺序排序
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      // 如果只有一个版本在顺序列表中，优先显示
      else if (indexA != -1) {
        return -1;
      }
      else if (indexB != -1) {
        return 1;
      }
      // 如果两个版本都不在顺序列表中，按字符串排序
      else {
        return a.compareTo(b);
      }
    });
    
    return versions;
  }

  // 获取流派列表（排除从maidata追加的歌曲）
  Future<List<String>> getGenreList() async {
    final manager = MaimaiMusicDataManager();
    final allSongs = await manager.getCachedSongs();
    
    if (allSongs == null || allSongs.isEmpty) {
      return [];
    }

    final genres = <String>{};
    for (var song in allSongs) {
      // 排除从maidata追加的歌曲（cids全为0表示从maidata解析）
      if (!_isMaidataSong(song)) {
        genres.add(song.basicInfo.genre);
      }
    }

    return genres.toList();
  }
  
  // 判断是否是从maidata追加的歌曲（cids全为0表示从maidata解析）
  bool _isMaidataSong(Song song) {
    if (song.cids.isEmpty) return false;
    return song.cids.every((cid) => cid == 0);
  }
}