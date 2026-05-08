import 'package:my_first_flutter_app/entity/Multiplayer/PlayerEntity.dart';
import 'package:my_first_flutter_app/entity/GameType.dart';

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
  }) : _roomCode = roomCode,
       lastActivityAt = lastActivityAt ?? createdAt;

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
    );
  }

  /// 转换为JSON（使用 snake_case，与数据库表结构一致）
  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'game_type': gameType.name,
      'players': players.map((p) => p.toJson()).toList(),
      'status': status.name,
      'max_players': maxPlayers,
      'creator_id': creatorId,
      'time_limit': timeLimit,
      'max_guesses': maxGuesses,
      'total_rounds': totalRounds,
      'created_at': createdAt.toIso8601String(),
      'last_activity_at': lastActivityAt.toIso8601String(),
    };
  }

  /// 创建副本并更新属性
  RoomEntity copyWith({
    String? roomId,
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
  }) {
    return RoomEntity(
      roomId: roomId ?? this.roomId,
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
    );
  }

  static GameType _parseGameType(String? type) {
    switch (type) {
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
      default:
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