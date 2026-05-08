import 'package:my_first_flutter_app/manager/UserPlayDataManager.dart';
import 'package:my_first_flutter_app/manager/MaimaiMusicDataManager.dart';

class PersonalizedBest50Service {
  // 单例模式
  static final PersonalizedBest50Service _instance = PersonalizedBest50Service._internal();
  factory PersonalizedBest50Service() => _instance;
  PersonalizedBest50Service._internal();

  // 获取AP+50数据
  Future<Map<String, dynamic>?> getAPPlus50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 过滤出fc字段为app的记录
      final appRecords = userPlayData['records']?.where((record) {
        return record['fc'] == 'app';
      }).toList() ?? [];

      // 按ra值降序排序
      appRecords.sort((a, b) {
        int raB = (b['ra'] ?? 0) as int;
        int raA = (a['ra'] ?? 0) as int;
        return raB.compareTo(raA);
      });

      // 取前50条
      final top50Records = appRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'ap_plus_50'
      };
    } catch (e) {
      print('获取AP+50数据时出错: $e');
      return null;
    }
  }

  // 获取AP50数据
  Future<Map<String, dynamic>?> getAP50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fc字段为ap的记录
      final apRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fc'] == 'ap';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      apRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = apRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'ap_50'
      };
    } catch (e) {
      print('获取AP50数据时出错: $e');
      return null;
    }
  }

  // 获取FC50数据
  Future<Map<String, dynamic>?> getFC50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fc字段为fc的记录
      final fcRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fc'] == 'fc';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      fcRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = fcRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'fc_50'
      };
    } catch (e) {
      print('获取FC50数据时出错: $e');
      return null;
    }
  }

  // 获取FC+50数据
  Future<Map<String, dynamic>?> getFCPlus50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fc字段为fcp的记录
      final fcpRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fc'] == 'fcp';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      fcpRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = fcpRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'fc_plus_50'
      };
    } catch (e) {
      print('获取FC+50数据时出错: $e');
      return null;
    }
  }

  // 获取寸50数据
  Future<Map<String, dynamic>?> getCun50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出achievements字段在[100.4800-100.4999]或[99.9800-99.9999]范围内的记录
      final cunRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          double achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
          return (achievements >= 100.4800 && achievements <= 100.4999) || 
                 (achievements >= 99.9800 && achievements <= 99.9999);
        }
        return false;
      }).toList();

      // 按ra值降序排序
      cunRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = cunRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'cun_50'
      };
    } catch (e) {
      print('获取寸50数据时出错: $e');
      return null;
    }
  }

  // 获取名刀50/锁血50数据
  Future<Map<String, dynamic>?> getMingDao50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出achievements字段在[100.0000,100.0500]或[100.5000,100.5500]范围内的记录
      final mingDaoRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          double achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
          return (achievements >= 100.0000 && achievements <= 100.0500) || 
                 (achievements >= 100.5000 && achievements <= 100.5500);
        }
        return false;
      }).toList();

      // 按ra值降序排序
      mingDaoRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = mingDaoRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'mingdao_50'
      };
    } catch (e) {
      print('获取名刀50/锁血50数据时出错: $e');
      return null;
    }
  }

  // 获取寸鸟加50数据
  Future<Map<String, dynamic>?> getCuniaoPlus50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出achievements字段在[100.4800-100.4999]范围内的记录
      final cuniaoPlusRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          double achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
          return achievements >= 100.4800 && achievements <= 100.4999;
        }
        return false;
      }).toList();

      // 按ra值降序排序
      cuniaoPlusRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = cuniaoPlusRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'cuniao_plus_50'
      };
    } catch (e) {
      print('获取寸鸟加50数据时出错: $e');
      return null;
    }
  }

  // 获取锁血鸟加50数据
  Future<Map<String, dynamic>?> getSuoxuePlus50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出achievements字段在[100.5000,100.5500]范围内的记录
      final suoxuePlusRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          double achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
          return achievements >= 100.5000 && achievements <= 100.5500;
        }
        return false;
      }).toList();

      // 按ra值降序排序
      suoxuePlusRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = suoxuePlusRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'suoxue_plus_50'
      };
    } catch (e) {
      print('获取锁血鸟加50数据时出错: $e');
      return null;
    }
  }

  // 获取寸鸟50数据
  Future<Map<String, dynamic>?> getCuniao50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出achievements字段在[99.9800-99.9999]范围内的记录
      final cuniaoRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          double achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
          return achievements >= 99.9800 && achievements <= 99.9999;
        }
        return false;
      }).toList();

      // 按ra值降序排序
      cuniaoRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = cuniaoRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'cuniao_50'
      };
    } catch (e) {
      print('获取寸鸟50数据时出错: $e');
      return null;
    }
  }

  // 获取锁血鸟50数据
  Future<Map<String, dynamic>?> getSuoxue50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出achievements字段在[100.0000,100.0500]范围内的记录
      final suoxueRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          double achievements = double.tryParse(record['achievements'].toString()) ?? 0.0;
          return achievements >= 100.0000 && achievements <= 100.0500;
        }
        return false;
      }).toList();

      // 按ra值降序排序
      suoxueRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = suoxueRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'suoxue_50'
      };
    } catch (e) {
      print('获取锁血鸟50数据时出错: $e');
      return null;
    }
  }

  // 为记录添加歌曲信息
  Future<List<Map<String, dynamic>>> enrichRecordsWithSongInfo(dynamic records) async {
    try {
      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return [];

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 确保records是List类型
      final List<dynamic> recordsList = records is List ? records : [];

      // 为每条记录添加歌曲信息
      List<Map<String, dynamic>> result = [];
      for (var record in recordsList) {
        if (record is Map<String, dynamic>) {
          final songId = record['song_id'];
          final song = songMap[songId.toString()];
          
          if (song != null) {
            // 获取 level_index
            final levelIndex = record['level_index'] ?? 0;
            // 根据 level_index 获取对应的定数值
            double dsValue = 0.0;
            if (levelIndex >= 0 && levelIndex < song.ds.length) {
              dsValue = song.ds[levelIndex];
            }
            
            result.add({
              ...record,
              'title': song.title,
              'type': song.type,
              'ds': dsValue,
              'level': song.level,
            });
          } else {
            result.add(record);
          }
        }
      }
      return result;
    } catch (e) {
      print('为记录添加歌曲信息时出错: $e');
      return [];
    }
  }

  // 获取charter出现次数
  Future<Map<String, int>> getCharterCounts() async {
    try {
      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return {};

      // 统计charter出现次数
      Map<String, int> charterCounts = {};
      for (var song in allSongs) {
        for (var chart in song.charts) {
          if (chart.charter.isNotEmpty) {
            String charter = chart.charter;
            charterCounts[charter] = (charterCounts[charter] ?? 0) + 1;
          }
        }
      }

      // 筛选出出现次数大于等于10次的charter
      Map<String, int> filteredCharterCounts = {};
      charterCounts.forEach((charter, count) {
        if (count >= 10) {
          filteredCharterCounts[charter] = count;
        }
      });

      return filteredCharterCounts;
    } catch (e) {
      print('获取charter出现次数时出错: $e');
      return {};
    }
  }

  // 获取特定charter的top50记录
  Future<Map<String, dynamic>?> getCharter50Data(String charter) async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 过滤出该charter的谱面的记录
      final charterRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          final songId = record['song_id'];
          final levelIndex = record['level_index'] ?? 0;
          final song = songMap[songId.toString()];
          
          if (song != null && levelIndex >= 0 && levelIndex < song.charts.length) {
            return song.charts[levelIndex].charter == charter;
          }
        }
        return false;
      }).toList();

      // 按ra值降序排序
      charterRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = charterRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'charter_50',
        'charter': charter
      };
    } catch (e) {
      print('获取charter50数据时出错: $e');
      return null;
    }
  }

  // 获取版本列表
  Future<Map<String, int>> getVersionCounts() async {
    try {
      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return {};

      // 统计版本出现次数
      Map<String, int> versionCounts = {};
      for (var song in allSongs) {
        String version = song.basicInfo.from;
        versionCounts[version] = (versionCounts[version] ?? 0) + 1;
      }

      return versionCounts;
    } catch (e) {
      print('获取版本出现次数时出错: $e');
      return {};
    }
  }

  // 获取特定版本的top50记录
  Future<Map<String, dynamic>?> getVersion50Data(String version) async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 过滤出该版本的歌曲的记录
      final versionRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          final songId = record['song_id'];
          final song = songMap[songId.toString()];
          
          if (song != null) {
            return song.basicInfo.from == version;
          }
        }
        return false;
      }).toList();

      // 按ra值降序排序
      versionRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = versionRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'version_50',
        'version': version
      };
    } catch (e) {
      print('获取version50数据时出错: $e');
      return null;
    }
  }

  // 获取DX50数据
  Future<Map<String, dynamic>?> getDX50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 过滤出类型为DX的歌曲的记录
      final dxRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          final songId = record['song_id'];
          final song = songMap[songId.toString()];
          
          if (song != null) {
            return song.type == 'DX';
          }
        }
        return false;
      }).toList();

      // 按ra值降序排序
      dxRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = dxRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'dx_50'
      };
    } catch (e) {
      print('获取DX50数据时出错: $e');
      return null;
    }
  }

  // 获取ST50数据
  Future<Map<String, dynamic>?> getST50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 过滤出类型为SD的歌曲的记录
      final stRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          final songId = record['song_id'];
          final song = songMap[songId.toString()];
          
          if (song != null) {
            return song.type == 'SD';
          }
        }
        return false;
      }).toList();

      // 按ra值降序排序
      stRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = stRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'st_50'
      };
    } catch (e) {
      print('获取ST50数据时出错: $e');
      return null;
    }
  }

  // 获取FS50数据
  Future<Map<String, dynamic>?> getFS50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fs字段为fs的记录
      final fsRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fs'] == 'fs';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      fsRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = fsRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'fs_50'
      };
    } catch (e) {
      print('获取FS50数据时出错: $e');
      return null;
    }
  }

  // 获取FS+50数据
  Future<Map<String, dynamic>?> getFSPlus50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fs字段为fsp的记录
      final fspRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fs'] == 'fsp';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      fspRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = fspRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'fs_plus_50'
      };
    } catch (e) {
      print('获取FS+50数据时出错: $e');
      return null;
    }
  }

  // 获取FDX50数据
  Future<Map<String, dynamic>?> getFDX50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fs字段为fsd的记录
      final fsdRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fs'] == 'fsd';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      fsdRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = fsdRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'fsd_50'
      };
    } catch (e) {
      print('获取FDX50数据时出错: $e');
      return null;
    }
  }

  // 获取FDX+50数据
  Future<Map<String, dynamic>?> getFDXPlus50Data() async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 过滤出fs字段为fsdp的记录
      final fsdpRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          return record['fs'] == 'fsdp';
        }
        return false;
      }).toList();

      // 按ra值降序排序
      fsdpRecords.sort((a, b) {
        if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
          int raB = (b['ra'] ?? 0) as int;
          int raA = (a['ra'] ?? 0) as int;
          return raB.compareTo(raA);
        }
        return 0;
      });

      // 取前50条
      final top50Records = fsdpRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'fsdp_50'
      };
    } catch (e) {
      print('获取FDX+50数据时出错: $e');
      return null;
    }
  }

  // 获取流派列表
  Future<Map<String, int>> getGenreCounts() async {
    try {
      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return {};

      // 统计流派出现次数
      Map<String, int> genreCounts = {};
      for (var song in allSongs) {
        String genre = song.basicInfo.genre;
        if (genre.isNotEmpty) {
          genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
        }
      }

      return genreCounts;
    } catch (e) {
      print('获取流派出现次数时出错: $e');
      return {};
    }
  }

  // 获取特定流派的top50记录
  Future<Map<String, dynamic>?> getGenre50Data(String genre) async {
    try {
      // 获取用户游玩数据
      final userPlayData = await UserPlayDataManager().getCachedUserPlayData();
      if (userPlayData == null) return null;

      // 确保records是List类型
      final records = userPlayData['records'];
      if (!(records is List)) return null;

      // 获取所有歌曲数据
      final allSongs = await MaimaiMusicDataManager().getCachedSongs();
      if (allSongs == null) return null;

      // 构建歌曲ID到歌曲信息的映射
      final songMap = { for (var song in allSongs) song.id: song };

      // 过滤出该流派的歌曲的记录
      final genreRecords = records.where((record) {
        if (record is Map<String, dynamic>) {
          final songId = record['song_id'];
          final song = songMap[songId.toString()];
          
          if (song != null) {
            return song.basicInfo.genre == genre;
          }
        }
        return false;
      }).toList();

      // 排序：如果是\u5bb4\u4f1a\u5834（宴会场）流派，按达成率降序排序；否则按ra值降序排序
      if (genre == '\u5bb4\u4f1a\u5834') {
        genreRecords.sort((a, b) {
          if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
            double achievementsB = double.tryParse(b['achievements'].toString()) ?? 0.0;
            double achievementsA = double.tryParse(a['achievements'].toString()) ?? 0.0;
            return achievementsB.compareTo(achievementsA);
          }
          return 0;
        });
      } else {
        genreRecords.sort((a, b) {
          if (a is Map<String, dynamic> && b is Map<String, dynamic>) {
            int raB = (b['ra'] ?? 0) as int;
            int raA = (a['ra'] ?? 0) as int;
            return raB.compareTo(raA);
          }
          return 0;
        });
      }

      // 取前50条
      final top50Records = genreRecords.take(50).toList();

      // 构建返回数据
      return {
        'records': top50Records,
        'total': top50Records.length,
        'type': 'genre_50',
        'genre': genre
      };
    } catch (e) {
      print('获取genre50数据时出错: $e');
      return null;
    }
  }
}