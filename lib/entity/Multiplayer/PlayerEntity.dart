import 'package:shared_preferences/shared_preferences.dart';

/// 玩家实体类
class PlayerEntity {
  /// 玩家ID
  final String playerId;
  
  /// 玩家昵称（从缓存获取）
  final String nickname;
  
  /// 分数
  final int score;
  
  /// 是否是房主
  final bool isHost;
  
  /// 是否准备就绪
  final bool isReady;
  
  /// 是否在线
  final bool isOnline;
  
  /// 是否投降
  final bool isSurrendered;

  PlayerEntity({
    required this.playerId,
    required this.nickname,
    this.score = 0,
    this.isHost = false,
    this.isReady = false,
    this.isOnline = true,
    this.isSurrendered = false,
  });

  /// 从JSON解析（支持 snake_case、camelCase 和后端字段）
  factory PlayerEntity.fromJson(Map<String, dynamic> json) {
    return PlayerEntity(
      playerId: json['player_id'] ?? json['playerId'] ?? json['id'] ?? '',
      nickname: json['nickname'] ?? '玩家',
      score: json['score'] ?? 0,
      isHost: json['is_host'] ?? json['isHost'] ?? json['host'] ?? false,
      isReady: json['is_ready'] ?? json['isReady'] ?? json['ready'] ?? false,
      isOnline: json['is_online'] ?? json['isOnline'] ?? json['online'] ?? true,
      isSurrendered: json['is_surrendered'] ?? json['isSurrendered'] ?? json['surrendered'] ?? false,
    );
  }

  /// 转换为JSON（使用 snake_case，与数据库表结构一致）
  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'nickname': nickname,
      'score': score,
      'is_host': isHost,
      'is_ready': isReady,
      'is_online': isOnline,
      'is_surrendered': isSurrendered,
    };
  }

  /// 创建副本并更新属性
  PlayerEntity copyWith({
    String? playerId,
    String? nickname,
    int? score,
    bool? isHost,
    bool? isReady,
    bool? isOnline,
    bool? isSurrendered,
  }) {
    return PlayerEntity(
      playerId: playerId ?? this.playerId,
      nickname: nickname ?? this.nickname,
      score: score ?? this.score,
      isHost: isHost ?? this.isHost,
      isReady: isReady ?? this.isReady,
      isOnline: isOnline ?? this.isOnline,
      isSurrendered: isSurrendered ?? this.isSurrendered,
    );
  }

  /// 从缓存获取玩家昵称（与首页使用相同的键名）
  static Future<String> getCachedNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userNickname') ?? '玩家';
  }

  /// 保存玩家昵称到缓存（与首页使用相同的键名）
  static Future<void> saveNicknameToCache(String nickname) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userNickname', nickname);
  }
}