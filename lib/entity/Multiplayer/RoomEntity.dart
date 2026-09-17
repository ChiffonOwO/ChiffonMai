import 'package:flutter/foundation.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/entity/Multiplayer/GameType.dart';

/// 房间实体类
class RoomEntity {
  /// 房间ID
  final String roomId;
  
  /// 房间码（6位数字）- 私有字段
  final String _roomCode;
  
  /// 游戏类型
  final GameType gameType;
  
  /// 玩家列表
  final List<PlayerEntity> players;
  
  /// 房间状态
  final RoomStatus status;
  
  /// 最大玩家数
  final int maxPlayers;
  
  /// 创建者ID
  final String creatorId;
  
  /// 时间限制（秒）
  final int timeLimit;
  
  /// 最大猜测次数
  final int maxGuesses;
  
  /// 总回合数
  final int totalRounds;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 最后活动时间
  final DateTime lastActivityAt;
  
  /// 选中的版本列表（歌曲筛选参数）
  final List<String> selectedVersions;
  
  /// MASTER定数最小值
  final double masterMinDx;
  
  /// MASTER定数最大值
  final double masterMaxDx;
  
  /// 选中的流派列表（歌曲筛选参数）
  final List<String> selectedGenres;

  // ==================== 游戏模式专属设置 ====================
  /// 模糊程度（0-100），用于 blurred 模式
  final int blurLevel;

  /// 音频片段播放时长（秒），用于 audio 模式
  final int playDuration;

  /// 每次抽取歌曲数，用于 letters 模式
  final int songCount;

  /// 非英文字符过滤阈值（0-100），用于 letters 模式
  final int nonEnglishCharThreshold;

  /// 快闪时长（毫秒），用于 flash 模式
  final int flashDurationMs;

  /// 拼图切块总数，用于 tileReveal 模式
  final int tileCount;

  /// 拼图每批揭示间隔（毫秒），用于 tileReveal 模式
  final int tileRevealIntervalMs;

  /// 谱面片段时长（秒），用于 chartPeek 模式
  final int peekDurationSeconds;

  /// 谱面片段难度随机池（inote 编号 '2'..'6'），用于 chartPeek 模式
  final List<String> peekDifficulties;

  /// 模式专属设置的默认值（与构造参数默认值同一份，供 [withModeSettingsFallback] 判断）。
  static const int defaultFlashDurationMs = 300;
  static const int defaultTileCount = 1000;
  static const int defaultTileRevealIntervalMs = 1500;
  static const int defaultPeekDurationSeconds = 8;
  static const List<String> defaultPeekDifficulties = ['4'];

  RoomEntity({
    required this.roomId,
    String roomCode = '',
    required this.gameType,
    required this.players,
    required this.status,
    required this.maxPlayers,
    required this.creatorId,
    required this.timeLimit,
    required this.maxGuesses,
    required this.createdAt,
    DateTime? lastActivityAt,
    this.totalRounds = 5,
    this.selectedVersions = const [],
    this.masterMinDx = 1.0,
    this.masterMaxDx = 15.0,
    this.selectedGenres = const [],
    this.blurLevel = 50,
    this.playDuration = 5,
    this.songCount = 3,
    this.nonEnglishCharThreshold = 50,
    this.flashDurationMs = defaultFlashDurationMs,
    this.tileCount = defaultTileCount,
    this.tileRevealIntervalMs = defaultTileRevealIntervalMs,
    this.peekDurationSeconds = defaultPeekDurationSeconds,
    this.peekDifficulties = defaultPeekDifficulties,
  }) : _roomCode = roomCode,
       lastActivityAt = lastActivityAt ?? createdAt;

  /// 用 [fallback] 兜住「服务端这次没下发」的模式专属设置。
  ///
  /// 为什么需要：模式设置（切块数 / 揭示间隔 / 快闪时长 / 片段时长 / 难度池）
  /// **在房间创建后不可修改**，所以同一房间内本地已经拿到的值永远有效。
  /// 而 `fromJson` 对缺失字段只能退回默认值，一旦某条房间事件（老服务端 /
  /// 精简过的 getState）没带这些字段，界面就会从「2500 块」掉回「1000 块」——
  /// 这正是「自定义切块数量进游戏后失效」那类问题的成因之一。
  ///
  /// 判定方式：本实体里仍是**默认值**、而 [fallback] 里是**非默认值**时，
  /// 采用 fallback 的值。房主真的用默认值建房时两边都是默认值，不受影响。
  RoomEntity withModeSettingsFallback(RoomEntity? fallback) {
    if (fallback == null) return this;
    return copyWith(
      flashDurationMs: flashDurationMs == defaultFlashDurationMs
          ? fallback.flashDurationMs
          : flashDurationMs,
      tileCount: tileCount == defaultTileCount ? fallback.tileCount : tileCount,
      tileRevealIntervalMs: tileRevealIntervalMs == defaultTileRevealIntervalMs
          ? fallback.tileRevealIntervalMs
          : tileRevealIntervalMs,
      peekDurationSeconds: peekDurationSeconds == defaultPeekDurationSeconds
          ? fallback.peekDurationSeconds
          : peekDurationSeconds,
      peekDifficulties: peekDifficulties.length == 1 &&
              peekDifficulties.first == defaultPeekDifficulties.first
          ? fallback.peekDifficulties
          : peekDifficulties,
    );
  }

  /// 从JSON解析（支持 snake_case、camelCase 和后端字段）
  factory RoomEntity.fromJson(Map<String, dynamic> json) {
    List<dynamic>? playersJson = json['players'] as List<dynamic>?;
    List<PlayerEntity> playersList = [];
    if (playersJson != null) {
      playersList = playersJson.map((e) => PlayerEntity.fromJson(e)).toList();
    }
    
    String roomId = json['room_id'] ?? json['roomId'] ?? json['id'] ?? '';
    
    // 处理时间戳（支持数字和字符串格式）
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is int) {
        // 后端返回的是毫秒时间戳
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }
    
    // 解析歌曲筛选参数
    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
      return [];
    }
    
    int parseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      return int.tryParse(value.toString()) ?? defaultValue;
    }

    /// 定数范围：后端可能给 double / int / 字符串，缺省时回落到默认区间。
    double parseDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return RoomEntity(
      roomId: roomId,
      roomCode: json['room_code'] ?? json['roomCode'] ?? json['code'] ?? '',
      gameType: _parseGameType(json['game_type'] ?? json['gameType']),
      players: playersList,
      status: _parseRoomStatus(json['status']),
      maxPlayers: json['max_players'] ?? json['maxPlayers'] ?? 4,
      creatorId: json['creator_id'] ?? json['creatorId'] ?? json['creator'] ?? json['hostId'] ?? '',
      timeLimit: json['time_limit'] ?? json['timeLimit'] ?? 60,
      maxGuesses: json['max_guesses'] ?? json['maxGuesses'] ?? 10,
      totalRounds: json['total_rounds'] ?? json['totalRounds'] ?? 5,
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      lastActivityAt: parseDateTime(json['last_activity_at'] ?? json['lastActivityAt']),
      selectedVersions: parseStringList(json['selectedVersions'] ?? json['selected_versions']),
      // 注意：这里原来的三元写法在**两个 key 都缺失**时会返回 null
      // （true 分支里没有兜底值），minimal 报文（老服务端 / 单测构造）会直接抛
      // 类型错误。改成 num?.toDouble() + 兜底。
      masterMinDx: parseDouble(json['masterMinDx'] ?? json['master_min_dx'], 1.0),
      masterMaxDx: parseDouble(json['masterMaxDx'] ?? json['master_max_dx'], 15.0),
      selectedGenres: parseStringList(json['selectedGenres'] ?? json['selected_genres']),
      blurLevel: parseInt(json['blur_level'] ?? json['blurLevel'], 50),
      playDuration: parseInt(json['play_duration'] ?? json['playDuration'], 5),
      songCount: parseInt(json['song_count'] ?? json['songCount'], 3),
      nonEnglishCharThreshold: parseInt(json['non_english_char_threshold'] ?? json['nonEnglishCharThreshold'], 50),
      flashDurationMs: parseInt(json['flash_duration_ms'] ?? json['flashDurationMs'], 300),
      tileCount: parseInt(json['tile_count'] ?? json['tileCount'], 1000),
      tileRevealIntervalMs: parseInt(json['tile_reveal_interval_ms'] ?? json['tileRevealIntervalMs'], 1500),
      peekDurationSeconds: parseInt(json['peek_duration_seconds'] ?? json['peekDurationSeconds'], 8),
      peekDifficulties: parseStringList(json['peek_difficulties'] ?? json['peekDifficulties']).isEmpty
          ? const ['4']
          : parseStringList(json['peek_difficulties'] ?? json['peekDifficulties']),
    );
  }

  /// 转换为JSON（使用 snake_case，与数据库表结构一致）
  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'game_type': gameType.apiKey,
      'players': players.map((p) => p.toJson()).toList(),
      'status': status.name,
      'max_players': maxPlayers,
      'creator_id': creatorId,
      'time_limit': timeLimit,
      'max_guesses': maxGuesses,
      'total_rounds': totalRounds,
      'created_at': createdAt.toIso8601String(),
      'last_activity_at': lastActivityAt.toIso8601String(),
      'selected_versions': selectedVersions,
      'master_min_dx': masterMinDx,
      'master_max_dx': masterMaxDx,
      'selected_genres': selectedGenres,
      'blur_level': blurLevel,
      'play_duration': playDuration,
      'song_count': songCount,
      'non_english_char_threshold': nonEnglishCharThreshold,
      'flash_duration_ms': flashDurationMs,
      'tile_count': tileCount,
      'tile_reveal_interval_ms': tileRevealIntervalMs,
      'peek_duration_seconds': peekDurationSeconds,
      'peek_difficulties': peekDifficulties,
    };
  }

  /// 创建副本并更新属性
  RoomEntity copyWith({
    String? roomId,
    String? roomCode,
    GameType? gameType,
    List<PlayerEntity>? players,
    RoomStatus? status,
    int? maxPlayers,
    String? creatorId,
    int? timeLimit,
    int? maxGuesses,
    int? totalRounds,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    List<String>? selectedVersions,
    double? masterMinDx,
    double? masterMaxDx,
    List<String>? selectedGenres,
    int? blurLevel,
    int? playDuration,
    int? songCount,
    int? nonEnglishCharThreshold,
    int? flashDurationMs,
    int? tileCount,
    int? tileRevealIntervalMs,
    int? peekDurationSeconds,
    List<String>? peekDifficulties,
  }) {
    return RoomEntity(
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? _roomCode,
      gameType: gameType ?? this.gameType,
      players: players ?? this.players,
      status: status ?? this.status,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      creatorId: creatorId ?? this.creatorId,
      timeLimit: timeLimit ?? this.timeLimit,
      maxGuesses: maxGuesses ?? this.maxGuesses,
      totalRounds: totalRounds ?? this.totalRounds,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      selectedVersions: selectedVersions ?? this.selectedVersions,
      masterMinDx: masterMinDx ?? this.masterMinDx,
      masterMaxDx: masterMaxDx ?? this.masterMaxDx,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      blurLevel: blurLevel ?? this.blurLevel,
      playDuration: playDuration ?? this.playDuration,
      songCount: songCount ?? this.songCount,
      nonEnglishCharThreshold: nonEnglishCharThreshold ?? this.nonEnglishCharThreshold,
      flashDurationMs: flashDurationMs ?? this.flashDurationMs,
      tileCount: tileCount ?? this.tileCount,
      tileRevealIntervalMs: tileRevealIntervalMs ?? this.tileRevealIntervalMs,
      peekDurationSeconds: peekDurationSeconds ?? this.peekDurationSeconds,
      peekDifficulties: peekDifficulties ?? this.peekDifficulties,
    );
  }

  static GameType _parseGameType(String? type) {
    switch (type) {
      // 英文字段名（API 通信标准）
      case 'info':
        return GameType.info;
      case 'cover':
        return GameType.cover;
      case 'blurred':
        return GameType.blurred;
      case 'audio':
        return GameType.audio;
      case 'alia':
        return GameType.alia;
      case 'letters':
        return GameType.letters;
      case 'flash':
        return GameType.flash;
      case 'tileReveal':
      case 'tile_reveal':
        return GameType.tileReveal;
      case 'chartPeek':
      case 'chart_peek':
        return GameType.chartPeek;
      // 中文显示名（兼容旧版 / 服务端可能返回中文）
      case '无提示猜歌':
        return GameType.info;
      case '曲绘猜歌':
        return GameType.cover;
      case '模糊曲绘':
        return GameType.blurred;
      case '歌曲片段':
        return GameType.audio;
      case '别名猜歌':
        return GameType.alia;
      case '开字母':
        return GameType.letters;
      case '曲绘快闪':
        return GameType.flash;
      case '曲绘拼图':
        return GameType.tileReveal;
      case '谱面片段':
        return GameType.chartPeek;
      default:
        debugPrint('[WARN][RoomEntity] 未知的游戏类型: $type，默认使用 info');
        return GameType.info;
    }
  }

  static RoomStatus _parseRoomStatus(String? status) {
    switch (status) {
      case 'waiting':
        return RoomStatus.waiting;
      case 'playing':
        return RoomStatus.playing;
      case 'ended':
        return RoomStatus.ended;
      default:
        return RoomStatus.waiting;
    }
  }

  /// 获取短房间码（前8位字符）
  String get shortRoomId {
    if (roomId.length >= 8) {
      return roomId.substring(0, 8).toUpperCase();
    }
    return roomId.toUpperCase();
  }

  /// 获取房间码（优先使用后端返回的值，否则使用 roomId 生成）
  String get roomCode {
    if (_roomCode.isNotEmpty) return _roomCode;
    if (roomId.isEmpty) return '000000';
    
    // 使用 roomId 的哈希值生成6位数字
    int hash = roomId.hashCode.abs();
    return (hash % 1000000).toString().padLeft(6, '0');
  }
}

/// 房间状态枚举
enum RoomStatus {
  /// 等待中
  waiting,
  
  /// 游戏中
  playing,
  
  /// 已结束
  ended,
}

extension RoomStatusExtension on RoomStatus {
  String get name {
    switch (this) {
      case RoomStatus.waiting:
        return 'waiting';
      case RoomStatus.playing:
        return 'playing';
      case RoomStatus.ended:
        return 'ended';
    }
  }

  String get displayName {
    switch (this) {
      case RoomStatus.waiting:
        return '等待中';
      case RoomStatus.playing:
        return '游戏中';
      case RoomStatus.ended:
        return '已结束';
    }
  }
}